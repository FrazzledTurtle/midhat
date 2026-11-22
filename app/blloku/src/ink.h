#pragma once

#include <QColor>
#include <QImage>
#include <QQuickPaintedItem>
#include <QTimer>
#include <QVector>
#include <QtQml/qqmlregistration.h>

// Ink on a page: strokes kept in page units (640 wide) and saved as an SVG
// that any viewer shows. The item covers what is on screen; scroll is how far
// down the page that is, so long pages never need one huge texture.
// data-p on each path keeps the pressure per point.
class InkCanvas : public QQuickPaintedItem {
  Q_OBJECT
  QML_ELEMENT
  Q_PROPERTY(QString source READ source WRITE setSource NOTIFY sourceChanged)
  Q_PROPERTY(QColor ink MEMBER m_ink NOTIFY looksChanged)
  Q_PROPERTY(qreal scroll READ scroll WRITE setScroll NOTIFY scrollChanged)
  Q_PROPERTY(qreal contentHeight READ contentHeight NOTIFY contentChanged)
  Q_PROPERTY(bool empty READ empty NOTIFY contentChanged)
  Q_PROPERTY(QString error READ error NOTIFY errorChanged)

public:
  static constexpr qreal PageWidth = 640;

  explicit InkCanvas(QQuickItem *parent = nullptr);
  ~InkCanvas() override;

  QString source() const { return m_source; }
  void setSource(const QString &source);
  qreal contentHeight() const;
  bool empty() const { return m_strokes.isEmpty() && m_live.pts.isEmpty(); }
  QString error() const { return m_error; }
  qreal scroll() const { return m_scroll; }
  void setScroll(qreal scroll);

  Q_INVOKABLE void begin(qreal x, qreal y, qreal pressure);
  Q_INVOKABLE void extend(qreal x, qreal y, qreal pressure);
  Q_INVOKABLE void finish();
  Q_INVOKABLE void eraseAt(qreal x, qreal y);
  Q_INVOKABLE void endErase();
  Q_INVOKABLE bool undo();
  Q_INVOKABLE bool saveAs(const QString &path);
  Q_INVOKABLE void clear();

  void paint(QPainter *painter) override;

  struct Stroke {
    QVector<QPointF> pts;
    QVector<float> p;
  };
  static QByteArray toSvg(const QVector<Stroke> &strokes, const QColor &ink);
  static bool fromSvg(const QByteArray &svg, QVector<Stroke> *strokes);

signals:
  void sourceChanged();
  void looksChanged();
  void contentChanged();
  void errorChanged();
  void scrollChanged();

private:
  struct Op {
    bool added;
    QVector<Stroke> strokes;
    QVector<int> at;
  };

  qreal unit() const { return width() > 0 ? width() / PageWidth : 1; }
  void load();
  void changed();
  bool save();
  void drawStroke(QPainter &painter, const Stroke &stroke, qreal scale) const;
  void setError(const QString &error);

  QString m_source;
  QColor m_ink = QColor(0x11, 0x11, 0x11);
  qreal m_scroll = 0;
  QVector<Stroke> m_strokes;
  Stroke m_live;
  Op m_erasing;
  QVector<Op> m_undo;
  QImage m_cache;
  bool m_cacheValid = false;
  bool m_dirty = false;
  bool m_readOnly = false;
  QTimer m_saveTimer;
  QString m_error;
};
