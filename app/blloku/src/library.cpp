#include "library.h"

#include "page.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QLocale>
#include <QRegularExpression>
#include <QUrl>
#include <QVariantMap>

namespace {

const QString Daily = QStringLiteral("Ditari");

QDate dateOf(const QString &file) {
  return QDate::fromString(QFileInfo(file).completeBaseName(), Qt::ISODate);
}

QString readHead(const QString &file) {
  QFile f(file);
  return f.open(QIODevice::ReadOnly) ? QString::fromUtf8(f.read(4096)) : QString();
}

} // namespace

Library::Library(const QString &root, QObject *parent) : QObject(parent), m_root(root) {}

QString Library::titleFor(const QString &file) {
  const QDate day = dateOf(file);
  const QString date = day.isValid() ? QLocale::c().toString(day, QStringLiteral("ddd d MMM")) : QString();
  if (day.isValid() && QFileInfo(file).dir().dirName() == Daily)
    return date;
  static const QRegularExpression heading(QStringLiteral(R"(^#{1,3}\s+(.+?)\s*$)"), QRegularExpression::MultilineOption);
  if (const auto m = heading.match(readHead(file)); m.hasMatch())
    return m.captured(1);
  return day.isValid() ? date : QFileInfo(file).completeBaseName();
}

QVariantList Library::blloqe() const {
  QDir root(m_root);
  QStringList names = root.entryList(QDir::Dirs | QDir::NoDotAndDotDot, QDir::Name | QDir::IgnoreCase);
  names.removeIf([](const QString &n) { return n.endsWith(QLatin1String(".ink")); });
  if (!names.contains(Daily))
    names.prepend(Daily);
  else
    names.move(names.indexOf(Daily), 0);
  QVariantList out;
  for (const QString &name : names) {
    const QDir dir(root.filePath(name));
    out.append(QVariantMap{{QStringLiteral("name"), name},
                           {QStringLiteral("path"), dir.absolutePath()},
                           {QStringLiteral("count"), dir.entryList({QStringLiteral("*.md")}, QDir::Files).size()}});
  }
  return out;
}

QVariantList Library::pages(const QString &bllok) const {
  static const QRegularExpression marker(QStringLiteral(R"(^\s*(?:#{1,6}\s+|[-*+]\s+\[[ xX]\]\s+|[-*+]\s+|\d+[.)]\s+|>\s?))"));
  static const QRegularExpression skip(QStringLiteral(R"(^(?:!\[(?:ink|page)\]\(|```))"));
  const QDir dir(bllok);
  QVariantList out;
  for (const QFileInfo &info : dir.entryInfoList({QStringLiteral("*.md")}, QDir::Files, QDir::Time)) {
    const QString file = info.absoluteFilePath();
    QStringList preview;
    bool first = true;
    for (QString line : readHead(file).split(QLatin1Char('\n'))) {
      if (line.trimmed().isEmpty() || skip.match(line).hasMatch())
        continue;
      if (first && line.startsWith(QLatin1Char('#'))) {
        first = false;
        continue;
      }
      first = false;
      preview.append(line.remove(marker).trimmed());
      if (preview.size() == 4)
        break;
    }
    const QString ink = dir.filePath(info.completeBaseName() + QStringLiteral(".ink/page.svg"));
    out.append(QVariantMap{
        {QStringLiteral("file"), file},
        {QStringLiteral("title"), titleFor(file)},
        {QStringLiteral("when"), info.lastModified().date() == QDate::currentDate()
                                     ? QStringLiteral("today ") + info.lastModified().toString(QStringLiteral("HH:mm"))
                                     : QLocale::c().toString(info.lastModified(), QStringLiteral("ddd d MMM"))},
        {QStringLiteral("preview"), preview.join(QLatin1Char('\n'))},
        {QStringLiteral("ink"), QFile::exists(ink) ? QUrl::fromLocalFile(ink).toString() : QString()}});
  }
  return out;
}

QString Library::todayFile(QDate day) const {
  return QDir(m_root).filePath(Daily + QLatin1Char('/') + day.toString(Qt::ISODate) + QStringLiteral(".md"));
}

QString Library::newPageFile(const QString &bllok) const {
  const QDir dir(bllok);
  const QString stem = QDate::currentDate().toString(Qt::ISODate);
  QString file = dir.filePath(stem + QStringLiteral(".md"));
  for (int n = 2; QFile::exists(file); ++n)
    file = dir.filePath(QStringLiteral("%1-%2.md").arg(stem).arg(n));
  return file;
}

// A name typed by the user becomes a folder: one plain path segment, nothing else.
QString Library::newBllok(const QString &name) const {
  const QString clean = name.trimmed();
  static const QRegularExpression bad(QStringLiteral(R"([/\\\x00-\x1f])"));
  if (clean.isEmpty() || clean.startsWith(QLatin1Char('.')) || clean.endsWith(QLatin1String(".ink")) ||
      clean.size() > 80 || bad.match(clean).hasMatch())
    return QString();
  QDir root(m_root);
  if (!root.mkpath(clean))
    return QString();
  return root.absoluteFilePath(clean);
}

Page *Library::open(const QString &file) {
  const QString path = QFileInfo(file).absoluteFilePath();
  QString fresh;
  if (const QDate day = dateOf(path); day.isValid() && QFileInfo(path).dir().dirName() == Daily)
    fresh = QStringLiteral("# ") + QLocale::c().toString(day, QStringLiteral("dddd d MMMM yyyy")) + QStringLiteral("\n\n");
  if (m_current) {
    m_current->saveNow();
    m_current->deleteLater();
  }
  m_current = new Page(path, fresh, titleFor(path), this);
  return m_current;
}
