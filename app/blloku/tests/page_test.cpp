#include "page.h"

#include <QCoreApplication>
#include <QDir>
#include <QFile>
#include <QTemporaryDir>
#include <cstdio>

static int failures = 0;

static void check(bool ok, const char *what) {
  std::printf("%s - %s\n", ok ? "ok" : "not ok", what);
  if (!ok)
    ++failures;
}

static QString read(const QString &path) {
  QFile f(path);
  return f.open(QIODevice::ReadOnly) ? QString::fromUtf8(f.readAll()) : QString();
}

static void later(const QString &path) {
  QFile f(path);
  if (f.open(QIODevice::ReadWrite))
    f.setFileTime(QDateTime::currentDateTime().addSecs(5), QFileDevice::FileModificationTime);
}

static void write(const QString &path, const QString &text) {
  QFile f(path);
  if (f.open(QIODevice::WriteOnly))
    f.write(text.toUtf8());
}

int main(int argc, char *argv[]) {
  QCoreApplication app(argc, argv);
  QTemporaryDir tmp;
  const QDir dir(tmp.path());

  {
    const QString path = dir.filePath(QStringLiteral("Ditari/2026-11-21.md"));
    Page page(path, QStringLiteral("# Saturday\n\n"), QStringLiteral("Sat 21 Nov"));
    page.saveNow();
    check(!QFile::exists(path), "a fresh page writes nothing until edited");
    page.setBlockText(0, QStringLiteral("# Saturday\n\nbread"));
    page.saveNow();
    check(read(path) == QLatin1String("# Saturday\n\nbread\n"), "an edit saves, with a final newline");
  }

  {
    const QString path = dir.filePath(QStringLiteral("trip.md"));
    write(path, QStringLiteral("a\n![ink](t.ink/1.svg)\nb\n"));
    Page page(path, QString(), QStringLiteral("trip"));
    page.setBlockText(2, QStringLiteral("b changed\n"));
    page.saveNow();
    check(read(path) == QLatin1String("a\n![ink](t.ink/1.svg)\nb changed\n"), "editing one block keeps the others");
  }

  {
    const QString path = dir.filePath(QStringLiteral("shared.md"));
    write(path, QStringLiteral("mine\n"));
    Page page(path, QString(), QStringLiteral("shared"));
    write(path, QStringLiteral("edited in nvim\n"));
    later(path);
    page.setBlockText(0, QStringLiteral("mine, typed on\n"));
    page.saveNow();
    check(read(path) == QLatin1String("edited in nvim\n"), "an outside edit is never overwritten");
    const QStringList beside = dir.entryList({QStringLiteral("shared.blloku-*.md")});
    check(beside.size() == 1 && read(dir.filePath(beside.value(0))) == QLatin1String("mine, typed on\n"),
          "our version is saved beside it");
    check(!page.error().isEmpty(), "and the page says so");
  }

  {
    const QString path = dir.filePath(QStringLiteral("notes.md"));
    write(path, QStringLiteral("hello\n![ink](notes.ink/1.svg)\n"));
    Page page(path, QString(), QStringLiteral("notes"));
    const QString next = page.newInkFile();
    check(next == dir.filePath(QStringLiteral("notes.ink/2.svg")), "a new ink file skips the ones in use");
    check(page.inkFile(1) == dir.filePath(QStringLiteral("notes.ink/1.svg")), "an ink block finds its file");
    page.appendInk(next);
    page.appendText(QStringLiteral("after"));
    page.saveNow();
    check(read(path) == QLatin1String("hello\n![ink](notes.ink/1.svg)\n\n![ink](notes.ink/2.svg)\nafter\n"),
          "new ink and text blocks land at the end of the file");
  }

  {
    const QString path = dir.filePath(QStringLiteral("day.md"));
    write(path, QStringLiteral("houses\n"));
    Page page(path, QString(), QStringLiteral("day"));
    check(page.layerFile() == dir.filePath(QStringLiteral("day.ink/page.svg")), "the page's ink has a file before it exists");
    page.ensureLayer();
    page.ensureLayer();
    check(read(path) == QLatin1String("houses\n\n![page](day.ink/page.svg)\n"), "drawing lists the page's ink once");
  }

  {
    const QString path = dir.filePath(QStringLiteral("locked.md"));
    write(path, QStringLiteral("secret\n"));
    QFile::setPermissions(path, QFileDevice::Permissions());
    Page page(path, QString(), QStringLiteral("locked"));
    page.setBlockText(0, QStringLiteral("x"));
    page.saveNow();
    QFile::setPermissions(path, QFileDevice::ReadOwner | QFileDevice::WriteOwner);
    check(read(path) == QLatin1String("secret\n"), "an unreadable page is never saved over");
    check(!page.error().isEmpty(), "and the page says why");
  }

  return failures ? 1 : 0;
}
