#include "page.h"
#include "calc.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QRegularExpression>
#include <QSaveFile>
#include <QVariantMap>

Page::Page(const QString &path, const QString &fresh, const QString &title, QObject *parent)
    : QObject(parent), m_path(path), m_savePath(path), m_title(title) {
  m_timer.setSingleShot(true);
  m_timer.setInterval(800);
  connect(&m_timer, &QTimer::timeout, this, &Page::saveNow);

  QFile file(path);
  if (!file.exists()) {
    m_blocks = splitBlocks(fresh);
    recalc();
    return;
  }
  if (!file.open(QIODevice::ReadOnly)) {
    // Never show an empty page over a file we couldn't read: saving it would wipe it.
    m_savePath.clear();
    m_blocks = splitBlocks(QString());
    setError(QStringLiteral("Couldn't open %1: %2. Nothing will be saved.").arg(path, file.errorString()));
    return;
  }
  m_blocks = splitBlocks(QString::fromUtf8(file.readAll()));
  m_diskTime = QFileInfo(path).lastModified();
  recalc();
}

QString Page::bllok() const { return QFileInfo(m_path).dir().dirName(); }

QVariantList Page::blocks() const {
  QVariantList list;
  for (const Block &b : m_blocks)
    list.append(QVariantMap{{QStringLiteral("kind"), b.kind}, {QStringLiteral("text"), b.text}});
  return list;
}

void Page::setBlockText(int index, const QString &text) {
  if (index < 0 || index >= m_blocks.size() || m_blocks[index].text == text)
    return;
  m_blocks[index].text = text;
  m_dirty = true;
  m_timer.start();
  if (m_blocks[index].kind == QLatin1String("calc"))
    recalc();
}

void Page::setRate(double rate) {
  if (m_rate == rate)
    return;
  m_rate = rate;
  recalc();
}

// Answers per block (a list per calc block, one per inner line), worked out
// fresh each time so the file never holds them.
void Page::recalc() {
  Calc calc(m_rate);
  m_answers.clear();
  for (const Block &b : m_blocks) {
    QStringList lines;
    if (b.kind == QLatin1String("calc")) {
      const QStringList inner = b.text.split(QLatin1Char('\n')).mid(1);
      for (qsizetype i = 0; i + 1 < inner.size(); ++i)
        lines.append(calc.line(inner[i]));
    }
    m_answers.append(lines);
  }
  m_pageRate = calc.rateSet() ? calc.rate() : 0;
  emit answersChanged();
}

// A new calc block below the cursor's line; a text block is split there.
int Page::insertCalc(int index, int cursor) {
  int at = int(m_blocks.size());
  if (index >= 0 && index < m_blocks.size() && m_blocks[index].kind == QLatin1String("text")) {
    const QString text = m_blocks[index].text;
    const qsizetype nl = text.indexOf(QLatin1Char('\n'), qBound(0, cursor, int(text.size())));
    if (nl >= 0) {
      m_blocks[index].text = text.left(nl);
      m_blocks.insert(index + 1, {QStringLiteral("text"), text.mid(nl + 1)});
    }
    at = index + 1;
  }
  m_blocks.insert(at, {QStringLiteral("calc"), QStringLiteral("```calc\n\n```")});
  m_dirty = true;
  m_timer.start();
  recalc();
  emit blocksChanged();
  return at;
}

// Removes a block; text blocks that end up side by side become one again.
// Returns the index of the block before it (-1 when it was first).
int Page::removeBlock(int index) {
  if (index < 0 || index >= m_blocks.size())
    return -1;
  m_blocks.removeAt(index);
  const QLatin1String text("text");
  if (index > 0 && index < m_blocks.size() && m_blocks[index - 1].kind == text && m_blocks[index].kind == text) {
    m_blocks[index - 1].text += QLatin1Char('\n') + m_blocks[index].text;
    m_blocks.removeAt(index);
  }
  m_dirty = true;
  m_timer.start();
  recalc();
  emit blocksChanged();
  return index - 1;
}

QString Page::inkFile(int index) const {
  static const QRegularExpression ink(QStringLiteral(R"(^!\[ink\]\(([^)]*)\))"));
  if (index < 0 || index >= m_blocks.size())
    return QString();
  const auto m = ink.match(m_blocks[index].text);
  return m.hasMatch() ? QFileInfo(m_path).dir().filePath(m.captured(1)) : QString();
}

QString Page::newInkFile() const {
  const QFileInfo page(m_path);
  const QDir inkDir(page.dir().filePath(page.completeBaseName() + QStringLiteral(".ink")));
  for (int n = 1;; ++n) {
    const QString file = inkDir.filePath(QStringLiteral("%1.svg").arg(n));
    bool used = QFile::exists(file);
    for (int i = 0; !used && i < m_blocks.size(); ++i)
      used = inkFile(i) == file;
    if (!used)
      return file;
  }
}

void Page::appendInk(const QString &file) {
  const QString rel = QFileInfo(m_path).dir().relativeFilePath(file);
  m_blocks.append({QStringLiteral("ink"), QStringLiteral("![ink](%1)").arg(rel)});
  m_dirty = true;
  saveNow();
  emit blocksChanged();
}

void Page::appendText(const QString &text) {
  m_blocks.append({QStringLiteral("text"), text});
  m_dirty = true;
  m_timer.start();
  emit blocksChanged();
}

QString Page::layerFile() const {
  static const QRegularExpression layer(QStringLiteral(R"(^!\[page\]\(([^)]*)\))"));
  const QFileInfo page(m_path);
  for (const Block &b : m_blocks)
    if (const auto m = layer.match(b.text); b.kind == QLatin1String("layer") && m.hasMatch())
      return page.dir().filePath(m.captured(1));
  return page.dir().filePath(page.completeBaseName() + QStringLiteral(".ink/page.svg"));
}

// The page's ink is listed once, at the end, the first time something is drawn.
void Page::ensureLayer() {
  for (const Block &b : m_blocks)
    if (b.kind == QLatin1String("layer"))
      return;
  const QString rel = QFileInfo(m_path).dir().relativeFilePath(layerFile());
  m_blocks.append({QStringLiteral("layer"), QStringLiteral("![page](%1)").arg(rel)});
  m_dirty = true;
  saveNow();
}

void Page::saveNow() {
  m_timer.stop();
  if (!m_dirty || m_savePath.isEmpty())
    return;

  // Changed on disk since we read it (nvim, a sync)? Keep both: ours goes beside it.
  if (m_savePath == m_path) {
    const QFileInfo disk(m_path);
    if (disk.exists() && disk.lastModified() != m_diskTime) {
      m_savePath = disk.dir().filePath(disk.completeBaseName() + QStringLiteral(".blloku-") +
                                       QDateTime::currentDateTime().toString(QStringLiteral("HHmmss")) + QStringLiteral(".md"));
      setError(QStringLiteral("%1 changed on disk. Your version is saved as %2.")
                   .arg(disk.fileName(), QFileInfo(m_savePath).fileName()));
    }
  }

  QString text = joinBlocks(m_blocks);
  if (!text.isEmpty() && !text.endsWith(QLatin1Char('\n')))
    text += QLatin1Char('\n');

  QDir().mkpath(QFileInfo(m_savePath).absolutePath());
  QSaveFile file(m_savePath);
  if (!file.open(QIODevice::WriteOnly) || file.write(text.toUtf8()) < 0 || !file.commit()) {
    setError(QStringLiteral("Couldn't save %1: %2").arg(m_savePath, file.errorString()));
    return;
  }
  m_dirty = false;
  if (m_savePath == m_path) {
    m_diskTime = QFileInfo(m_path).lastModified();
    setError(QString());
  }
}

void Page::setError(const QString &error) {
  if (m_error == error)
    return;
  m_error = error;
  emit errorChanged();
}
