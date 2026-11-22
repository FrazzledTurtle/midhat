#include "blocks.h"

#include <QRegularExpression>
#include <QStringList>

QList<Block> splitBlocks(const QString &markdown) {
  static const QRegularExpression ink(QStringLiteral(R"(^!\[ink\]\([^)]*\)\s*$)"));
  static const QRegularExpression layer(QStringLiteral(R"(^!\[page\]\([^)]*\)\s*$)"));
  static const QRegularExpression calcOpen(QStringLiteral(R"(^```calc\s*$)"));
  static const QRegularExpression fenceClose(QStringLiteral(R"(^```\s*$)"));

  const QStringList lines = markdown.split(QLatin1Char('\n'));
  QList<Block> blocks;
  QStringList run;
  auto flush = [&] {
    if (!run.isEmpty()) {
      blocks.append({QStringLiteral("text"), run.join(QLatin1Char('\n'))});
      run.clear();
    }
  };
  auto take = [&](const QString &kind, qsizetype from, qsizetype to) {
    flush();
    blocks.append({kind, lines.mid(from, to - from + 1).join(QLatin1Char('\n'))});
  };

  for (qsizetype i = 0; i < lines.size(); ++i) {
    const QString &line = lines[i];
    if (layer.match(line).hasMatch()) {
      take(QStringLiteral("layer"), i, i);
      continue;
    }
    if (ink.match(line).hasMatch()) {
      take(QStringLiteral("ink"), i, i);
      continue;
    }
    if (calcOpen.match(line).hasMatch()) {
      qsizetype end = i + 1;
      while (end < lines.size() && !fenceClose.match(lines[end]).hasMatch())
        ++end;
      if (end < lines.size()) {
        take(QStringLiteral("calc"), i, end);
        i = end;
        continue;
      }
    }
    if (line.startsWith(QLatin1String("> [!claude]"))) {
      qsizetype end = i;
      while (end + 1 < lines.size() && lines[end + 1].startsWith(QLatin1Char('>')))
        ++end;
      take(QStringLiteral("claude"), i, end);
      i = end;
      continue;
    }
    run.append(line);
  }
  flush();
  return blocks;
}

QString joinBlocks(const QList<Block> &blocks) {
  QStringList parts;
  for (const Block &b : blocks)
    parts.append(b.text);
  return parts.join(QLatin1Char('\n'));
}
