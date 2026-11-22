#pragma once

#include <QList>
#include <QString>

// A page is its markdown file cut into blocks of whole lines; joining the
// blocks back gives the file byte for byte.
struct Block {
  QString kind; // text, ink, layer (the page's own ink), calc, claude
  QString text;
};

QList<Block> splitBlocks(const QString &markdown);
QString joinBlocks(const QList<Block> &blocks);
