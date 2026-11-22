#include "blocks.h"

#include <QStringList>
#include <cstdio>

static int failures = 0;

static void check(bool ok, const char *what) {
  std::printf("%s - %s\n", ok ? "ok" : "not ok", what);
  if (!ok)
    ++failures;
}

static QString kinds(const QList<Block> &blocks) {
  QStringList k;
  for (const Block &b : blocks)
    k.append(b.kind);
  return k.join(QLatin1Char(','));
}

int main() {
  const QString mixed = QStringLiteral(
      "# Berat trip\n\nhello\n![ink](2026-11-21.ink/1.svg)\n```calc\nroom = 4500 / 3\n```\n"
      "> [!claude] asked 14:02\n> Both fit into one morning.\nend\n");
  const auto blocks = splitBlocks(mixed);
  check(kinds(blocks) == QLatin1String("text,ink,calc,claude,text"), "mixed page splits into its block kinds");
  check(joinBlocks(blocks) == mixed, "mixed page joins back byte for byte");

  const QString open = QStringLiteral("a\n```calc\nx = 1\n");
  check(kinds(splitBlocks(open)) == QLatin1String("text"), "an unclosed calc fence stays text");
  check(joinBlocks(splitBlocks(open)) == open, "an unclosed calc fence keeps every line");

  check(joinBlocks(splitBlocks(QString())) == QString(), "an empty page stays empty");
  check(joinBlocks(splitBlocks(QStringLiteral("x\n\n\n"))) == QLatin1String("x\n\n\n"), "trailing blank lines survive");
  check(kinds(splitBlocks(QStringLiteral("![ink](a.svg) trailing words"))) == QLatin1String("text"),
        "an ink line with more on it is text");

  const QString layered = QStringLiteral("text\n![page](d.ink/page.svg)\nmore\n");
  check(kinds(splitBlocks(layered)) == QLatin1String("text,layer,text"), "the page's own ink is its own kind");
  check(joinBlocks(splitBlocks(layered)) == layered, "and keeps its line");

  return failures ? 1 : 0;
}
