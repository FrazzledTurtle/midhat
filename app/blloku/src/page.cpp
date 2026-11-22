#include "page.h"

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
