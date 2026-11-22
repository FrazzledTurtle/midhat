#include "library.h"
#include "page.h"

#include <QCoreApplication>
#include <QDir>
#include <QFile>
#include <QTemporaryDir>
#include <QVariantMap>
#include <cstdio>

static int failures = 0;

static void check(bool ok, const char *what) {
  std::printf("%s - %s\n", ok ? "ok" : "not ok", what);
  if (!ok)
    ++failures;
}

static void write(const QString &path, const QString &text) {
  QDir().mkpath(QFileInfo(path).absolutePath());
  QFile f(path);
  if (f.open(QIODevice::WriteOnly))
    f.write(text.toUtf8());
}

int main(int argc, char *argv[]) {
  QCoreApplication app(argc, argv);
  QTemporaryDir tmp;
  const QDir root(tmp.path());
  Library library(tmp.path());

  check(library.blloqe().value(0).toMap().value(QStringLiteral("name")) == QLatin1String("Ditari"),
        "Ditari is listed even before it exists");

  write(root.filePath(QStringLiteral("Udhëtime/berat.md")),
        QStringLiteral("# Berat trip\n\n- [ ] ask Arben\n![page](berat.ink/page.svg)\nCastle **morning**\n"));
  write(root.filePath(QStringLiteral("Udhëtime/berat.ink/page.svg")), QStringLiteral("<svg/>"));
  write(root.filePath(QStringLiteral("Ditari/2026-11-21.md")), QStringLiteral("# Saturday\n\nhouses\n"));
  root.mkpath(QStringLiteral("Ditari/2026-11-21.ink"));
  write(root.filePath(QStringLiteral("Arkiv/old.md")), QStringLiteral("no heading here\n"));

  QStringList names;
  for (const QVariant &b : library.blloqe())
    names.append(b.toMap().value(QStringLiteral("name")).toString());
  check(names == QStringList({QStringLiteral("Ditari"), QStringLiteral("Arkiv"), QStringLiteral("Udhëtime")}),
        "Ditari first, then the rest by name, ink folders left out");

  const QVariantMap trip = library.pages(root.filePath(QStringLiteral("Udhëtime"))).value(0).toMap();
  check(trip.value(QStringLiteral("title")) == QLatin1String("Berat trip"), "a page is titled by its heading");
  check(trip.value(QStringLiteral("preview")) == QLatin1String("ask Arben\nCastle **morning**"),
        "the preview drops the heading, markers and ink lines");
  check(trip.value(QStringLiteral("ink")).toString().endsWith(QLatin1String("berat.ink/page.svg")), "a page with ink shows it");
  check(Library::titleFor(root.filePath(QStringLiteral("Ditari/2026-11-21.md"))) == QLatin1String("Sat 21 Nov"),
        "a daily page is titled by its date");
  check(Library::titleFor(root.filePath(QStringLiteral("Arkiv/old.md"))) == QLatin1String("old"),
        "no heading falls back to the file name");

  const QString first = library.newPageFile(root.filePath(QStringLiteral("Arkiv")));
  write(first, QStringLiteral("x\n"));
  const QString second = library.newPageFile(root.filePath(QStringLiteral("Arkiv")));
  check(first != second && second.endsWith(QLatin1String("-2.md")), "a new page never reuses a file");

  check(library.newBllok(QStringLiteral("  Punë ")) == root.filePath(QStringLiteral("Punë")) &&
            QDir(root.filePath(QStringLiteral("Punë"))).exists(),
        "a new bllok becomes a folder");
  bool refused = true;
  for (const char *name : {"", "   ", "../outside", "a/b", ".hidden", "x.ink", "tab\there"})
    refused = refused && library.newBllok(QString::fromUtf8(name)).isEmpty();
  check(refused && !QDir(tmp.path() + QStringLiteral("/../outside")).exists(), "bad bllok names are refused");

  {
    const QString today = library.todayFile(QDate(2026, 11, 22));
    Page *page = library.open(today);
    check(page->blocks().value(0).toMap().value(QStringLiteral("text")).toString().startsWith(QLatin1String("# Sunday 22 November 2026")),
          "today's page starts with its date");
    page->setBlockText(0, QStringLiteral("# Sunday\n\nwrote this\n"));
    library.open(root.filePath(QStringLiteral("Arkiv/old.md")));
    QCoreApplication::processEvents();
    QFile f(today);
    check(f.open(QIODevice::ReadOnly) && f.readAll() == "# Sunday\n\nwrote this\n", "opening another page saves the one before");
  }

  return failures ? 1 : 0;
}
