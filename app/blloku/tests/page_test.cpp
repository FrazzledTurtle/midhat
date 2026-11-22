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

  {
    const QString path = dir.filePath(QStringLiteral("flat.md"));
    write(path, QStringLiteral("rent\n```calc\nroom = 4500 lek / 3\n\n€ = 100 lek\n```\nnotes\n```calc\nroom in €\n```\n"));
    Page page(path, QString(), QStringLiteral("flat"));
    const QVariantList a = page.answers();
    check(a.size() == 5, "one answer list per block");
    check(a[1].toStringList() == QStringList({QStringLiteral("1500 lek"), QString(), QStringLiteral("€1 = 100 lek")}),
          "a calc block answers line by line");
    check(a[3].toStringList() == QStringList({QStringLiteral("15 €")}), "names and the rate carry on down the page");
    check(page.pageRate() == 100, "the page's own rate is known");
    page.setBlockText(1, QStringLiteral("```calc\nroom = 6000 lek / 3\n```"));
    check(page.answers()[3].toStringList() == QStringList({QStringLiteral("? set a rate: € = … lek")}),
          "editing a calc block reworks the page");
    page.setRate(120);
    check(page.answers()[3].toStringList() == QStringList({QStringLiteral("16.67 €")}),
          "a remembered rate fills in when the page sets none");
    check(page.pageRate() == 0, "and isn't the page's own");
  }

  {
    const QString path = dir.filePath(QStringLiteral("split.md"));
    write(path, QStringLiteral("one\ntwo\n"));
    Page page(path, QString(), QStringLiteral("split"));
    check(page.insertCalc(0, 1) == 1, "a calc block goes after the cursor's block");
    page.setBlockText(1, QStringLiteral("```calc\n2 + 2\n```"));
    page.saveNow();
    check(read(path) == QLatin1String("one\n```calc\n2 + 2\n```\ntwo\n"), "it splits the text at the end of the cursor's line");
    check(page.removeBlock(1) == 0, "removing it points at the block before");
    page.saveNow();
    check(read(path) == QLatin1String("one\ntwo\n"), "and the text joins back as it was");
    check(page.insertCalc(-1, 0) == 1 && page.blocks().size() == 2, "with no text in focus it goes at the end");
  }

  return failures ? 1 : 0;
}
