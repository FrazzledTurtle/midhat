#pragma once

#include <QColor>
#include <QQuickTextDocument>
#include <QSyntaxHighlighter>
#include <QtQml/qqmlregistration.h>

// Styles markdown in place as you type; the characters themselves stay as typed.
// Every line also gets the paper's line height, so typing sits on the lines.
class MarkdownHighlighter : public QSyntaxHighlighter {
  Q_OBJECT
  QML_ELEMENT
  Q_PROPERTY(QQuickTextDocument *document READ quickDocument WRITE setQuickDocument)
  Q_PROPERTY(QColor muted MEMBER m_muted)
  Q_PROPERTY(int baseSize MEMBER m_baseSize)
  Q_PROPERTY(bool plain MEMBER m_plain)
  Q_PROPERTY(int lineHeight READ lineHeight WRITE setLineHeight)

public:
  explicit MarkdownHighlighter(QObject *parent = nullptr) : QSyntaxHighlighter(parent) {}

  QQuickTextDocument *quickDocument() const { return m_quick; }
  void setQuickDocument(QQuickTextDocument *doc);
  int lineHeight() const { return m_lineHeight; }
  void setLineHeight(int px);

protected:
  void highlightBlock(const QString &text) override;

private:
  template <typename F> void style(qsizetype from, qsizetype length, F change);
  void dim(qsizetype from, qsizetype length);
  void fixLineHeights(int from, int length);

  QQuickTextDocument *m_quick = nullptr;
  QColor m_muted = QColor(0x68, 0x68, 0x68);
  int m_baseSize = 17;
  int m_lineHeight = 0;
  bool m_fixing = false;
  bool m_plain = false;
};
