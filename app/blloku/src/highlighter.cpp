#include "highlighter.h"

#include <QRegularExpression>
#include <QTextBlock>
#include <QTextCursor>
#include <QTextDocument>

void MarkdownHighlighter::setQuickDocument(QQuickTextDocument *doc) {
  if (document())
    disconnect(document(), nullptr, this, nullptr);
  m_quick = doc;
  setDocument(doc ? doc->textDocument() : nullptr);
  if (!document())
    return;
  connect(document(), &QTextDocument::contentsChange, this,
          [this](int from, int, int added) { fixLineHeights(from, added); });
  fixLineHeights(0, document()->characterCount());
}

void MarkdownHighlighter::setLineHeight(int px) {
  m_lineHeight = px;
  if (document())
    fixLineHeights(0, document()->characterCount());
}

void MarkdownHighlighter::fixLineHeights(int from, int length) {
  if (m_fixing || m_lineHeight <= 0 || !document())
    return;
  m_fixing = true;
  QTextDocument *doc = document();
  const bool freshPage = !doc->isUndoAvailable();
  bool joined = false;
  for (QTextBlock b = doc->findBlock(from); b.isValid() && b.position() <= from + length; b = b.next()) {
    const QTextBlockFormat now = b.blockFormat();
    if (now.lineHeightType() == QTextBlockFormat::FixedHeight && now.lineHeight() == m_lineHeight)
      continue;
    QTextCursor cursor(b);
    // Part of the edit that caused it, so undo never stops on a format change.
    if (!joined) {
      cursor.joinPreviousEditBlock();
      joined = true;
    } else {
      cursor.beginEditBlock();
    }
    QTextBlockFormat fixed;
    fixed.setLineHeight(m_lineHeight, QTextBlockFormat::FixedHeight);
    cursor.mergeBlockFormat(fixed);
    cursor.endEditBlock();
  }
  // A page just opened has nothing to undo; formatting it shouldn't add any.
  if (joined && freshPage)
    doc->clearUndoRedoStacks();
  m_fixing = false;
}

template <typename F> void MarkdownHighlighter::style(qsizetype from, qsizetype length, F change) {
  for (qsizetype i = from; i < from + length; ++i) {
    QTextCharFormat f = format(int(i));
    change(f);
    setFormat(int(i), 1, f);
  }
}

void MarkdownHighlighter::dim(qsizetype from, qsizetype length) {
  style(from, length, [&](QTextCharFormat &f) { f.setForeground(m_muted); });
}

void MarkdownHighlighter::highlightBlock(const QString &text) {
  static const QRegularExpression fence(QStringLiteral(R"(^```)"));
  static const QRegularExpression heading(QStringLiteral(R"(^(#{1,3})\s)"));
  static const QRegularExpression task(QStringLiteral(R"(^(\s*[-*+] \[([ xX])\]\s))"));
  static const QRegularExpression item(QStringLiteral(R"(^(\s*(?:[-*+]|\d+[.)])\s))"));
  static const QRegularExpression quote(QStringLiteral(R"(^>\s?)"));
  static const QRegularExpression bold(QStringLiteral(R"((\*\*)([^*]+)(\*\*))"));
  static const QRegularExpression italic(QStringLiteral(R"((?<![*\w])(\*)([^*\s][^*]*)(\*)(?![*\w]))"));
  static const QRegularExpression code(QStringLiteral(R"((`)([^`]+)(`))"));

  const bool inFence = previousBlockState() == 1;
  if (fence.match(text).hasMatch()) {
    setCurrentBlockState(inFence ? 0 : 1);
    dim(0, text.size());
    return;
  }
  setCurrentBlockState(inFence ? 1 : 0);
  if (inFence) {
    style(0, text.size(), [](QTextCharFormat &f) { f.setFontFamilies({QStringLiteral("monospace")}); });
    return;
  }

  if (const auto m = heading.match(text); m.hasMatch()) {
    static const double scale[] = {1.6, 1.3, 1.15};
    const int px = int(m_baseSize * scale[m.capturedLength(1) - 1]);
    style(0, text.size(), [px](QTextCharFormat &f) {
      f.setFontWeight(QFont::DemiBold);
      f.setProperty(QTextFormat::FontPixelSize, px);
    });
    dim(0, m.capturedLength(1));
  } else if (const auto m = task.match(text); m.hasMatch()) {
    dim(0, m.capturedLength(1));
    if (m.captured(2) != QLatin1String(" ")) {
      dim(m.capturedLength(1), text.size() - m.capturedLength(1));
      style(m.capturedLength(1), text.size() - m.capturedLength(1), [](QTextCharFormat &f) { f.setFontStrikeOut(true); });
    }
  } else if (const auto m = item.match(text); m.hasMatch()) {
    dim(0, m.capturedLength(1));
  } else if (const auto m = quote.match(text); m.hasMatch()) {
    style(0, text.size(), [](QTextCharFormat &f) { f.setFontItalic(true); });
    dim(0, m.capturedLength(0));
  }

  auto inline_ = [&](const QRegularExpression &re, auto change) {
    for (auto it = re.globalMatch(text); it.hasNext();) {
      const auto m = it.next();
      style(m.capturedStart(2), m.capturedLength(2), change);
      dim(m.capturedStart(1), m.capturedLength(1));
      dim(m.capturedStart(3), m.capturedLength(3));
    }
  };
  inline_(bold, [](QTextCharFormat &f) { f.setFontWeight(QFont::Bold); });
  inline_(italic, [](QTextCharFormat &f) { f.setFontItalic(true); });
  inline_(code, [](QTextCharFormat &f) { f.setFontFamilies({QStringLiteral("monospace")}); });
}
