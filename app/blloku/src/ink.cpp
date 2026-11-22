#include "ink.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QPainter>
#include <QQuickWindow>
#include <QRegularExpression>
#include <QSaveFile>
#include <QXmlStreamReader>
#include <algorithm>
#include <cmath>

namespace {

constexpr qreal Margin = 80;
constexpr qreal EraseRadius = 12;

// No pressure (pen-hold on, or a mouse) draws an even line.
qreal strokeWidth(float p) { return p <= 0 ? 2.2 : 0.9 + 3.4 * qMin(1.0f, p); }

qreal segmentDistance(QPointF p, QPointF a, QPointF b) {
  const QPointF ab = b - a;
  const qreal len2 = QPointF::dotProduct(ab, ab);
  const qreal t = len2 > 0 ? qBound(0.0, QPointF::dotProduct(p - a, ab) / len2, 1.0) : 0.0;
  const QPointF d = p - (a + t * ab);
  return std::hypot(d.x(), d.y());
}

} // namespace

InkCanvas::InkCanvas(QQuickItem *parent) : QQuickPaintedItem(parent) {
  setAntialiasing(true);
  m_saveTimer.setSingleShot(true);
  m_saveTimer.setInterval(500);
  connect(&m_saveTimer, &QTimer::timeout, this, &InkCanvas::save);
  connect(this, &QQuickItem::widthChanged, this, [this] {
    m_cacheValid = false;
    emit contentChanged();
  });
  connect(this, &QQuickItem::heightChanged, this, [this] { m_cacheValid = false; });
  connect(this, &InkCanvas::looksChanged, this, [this] {
    m_cacheValid = false;
    update();
  });
}

InkCanvas::~InkCanvas() { save(); }

void InkCanvas::setScroll(qreal scroll) {
  if (qFuzzyCompare(scroll + 1, m_scroll + 1))
    return;
  m_scroll = scroll;
  m_cacheValid = false;
  emit scrollChanged();
  update();
}

void InkCanvas::setSource(const QString &source) {
  if (source == m_source)
    return;
  save();
  m_source = source;
  load();
  emit sourceChanged();
}

qreal InkCanvas::contentHeight() const {
  qreal bottom = 0;
  for (const Stroke &s : m_strokes)
    for (const QPointF &pt : s.pts)
      bottom = qMax(bottom, pt.y());
  for (const QPointF &pt : m_live.pts)
    bottom = qMax(bottom, pt.y());
  return empty() ? 0 : (bottom + Margin) * unit();
}

void InkCanvas::load() {
  m_strokes.clear();
  m_undo.clear();
  m_dirty = false;
  m_readOnly = false;
  setError(QString());
  if (!m_source.isEmpty() && QFile::exists(m_source)) {
    QFile file(m_source);
    if (!file.open(QIODevice::ReadOnly) || !fromSvg(file.readAll(), &m_strokes)) {
      m_readOnly = true;
      m_strokes.clear();
      setError(QStringLiteral("Couldn't read %1; it won't be changed.").arg(QFileInfo(m_source).fileName()));
    }
  }
  m_cacheValid = false;
  emit contentChanged();
  update();
}

void InkCanvas::begin(qreal x, qreal y, qreal pressure) {
  if (m_readOnly)
    return;
  m_live = {};
  extend(x, y, pressure);
}

void InkCanvas::extend(qreal x, qreal y, qreal pressure) {
  if (m_readOnly)
    return;
  const qreal u = unit();
  m_live.pts.append(QPointF(x / u, (y + m_scroll) / u));
  m_live.p.append(float(pressure));
  const qreal grow = 2 * strokeWidth(1) * u;
  QRectF dirty(QPointF(x, y), QSizeF(0, 0));
  if (m_live.pts.size() > 1)
    dirty = dirty.united(QRectF(m_live.pts[m_live.pts.size() - 2] * u - QPointF(0, m_scroll), QSizeF(0, 0)));
  update(dirty.adjusted(-grow, -grow, grow, grow).toAlignedRect());
  if (m_live.pts.size() % 8 == 1)
    emit contentChanged();
}

void InkCanvas::finish() {
  if (m_live.pts.isEmpty())
    return;
  m_strokes.append(m_live);
  m_undo.append({true, {m_live}, {int(m_strokes.size() - 1)}});
  m_live = {};
  changed();
}

void InkCanvas::eraseAt(qreal x, qreal y) {
  if (m_readOnly)
    return;
  const qreal u = unit();
  const QPointF at(x / u, (y + m_scroll) / u);
  for (int i = int(m_strokes.size()) - 1; i >= 0; --i) {
    const Stroke &s = m_strokes[i];
    bool hit = s.pts.size() == 1 && std::hypot(s.pts[0].x() - at.x(), s.pts[0].y() - at.y()) < EraseRadius;
    for (qsizetype k = 1; !hit && k < s.pts.size(); ++k)
      hit = segmentDistance(at, s.pts[k - 1], s.pts[k]) < EraseRadius;
    if (hit) {
      m_erasing.strokes.append(s);
      m_erasing.at.append(i);
      m_strokes.removeAt(i);
      m_cacheValid = false;
      update();
    }
  }
}

void InkCanvas::endErase() {
  if (m_erasing.strokes.isEmpty())
    return;
  m_erasing.added = false;
  m_undo.append(m_erasing);
  m_erasing = {};
  changed();
}

bool InkCanvas::undo() {
  if (m_undo.isEmpty() || m_readOnly)
    return false;
  const Op op = m_undo.takeLast();
  if (op.added) {
    m_strokes.removeAt(op.at.first());
  } else {
    // Removed one by one, each index as it was then: put back newest first.
    for (qsizetype i = op.at.size() - 1; i >= 0; --i)
      m_strokes.insert(qMin<qsizetype>(op.at[i], m_strokes.size()), op.strokes[i]);
  }
  changed();
  return true;
}

void InkCanvas::changed() {
  m_cacheValid = false;
  m_dirty = true;
  m_saveTimer.start();
  emit contentChanged();
  update();
}

void InkCanvas::clear() {
  m_source.clear();
  m_strokes.clear();
  m_undo.clear();
  m_live = {};
  m_dirty = false;
  m_cacheValid = false;
  emit sourceChanged();
  emit contentChanged();
  update();
}

bool InkCanvas::saveAs(const QString &path) {
  m_source = path;
  m_dirty = true;
  const bool ok = save();
  emit sourceChanged();
  return ok;
}

bool InkCanvas::save() {
  m_saveTimer.stop();
  if (!m_dirty || m_readOnly || m_source.isEmpty())
    return true;
  QDir().mkpath(QFileInfo(m_source).absolutePath());
  QSaveFile file(m_source);
  if (!file.open(QIODevice::WriteOnly) || file.write(toSvg(m_strokes, m_ink)) < 0 || !file.commit()) {
    setError(QStringLiteral("Couldn't save %1: %2").arg(m_source, file.errorString()));
    return false;
  }
  m_dirty = false;
  setError(QString());
  return true;
}

void InkCanvas::drawStroke(QPainter &painter, const Stroke &s, qreal scale) const {
  QPen pen(m_ink, 1, Qt::SolidLine, Qt::RoundCap, Qt::RoundJoin);
  if (s.pts.size() == 1) {
    pen.setWidthF(strokeWidth(s.p[0]) * scale);
    painter.setPen(pen);
    painter.drawPoint(s.pts[0] * scale);
    return;
  }
  for (qsizetype i = 1; i < s.pts.size(); ++i) {
    pen.setWidthF(strokeWidth((s.p[i - 1] + s.p[i]) / 2) * scale);
    painter.setPen(pen);
    painter.drawLine(s.pts[i - 1] * scale, s.pts[i] * scale);
  }
}

void InkCanvas::paint(QPainter *painter) {
  const qreal u = unit();
  painter->setRenderHint(QPainter::Antialiasing);
  const qreal dpr = window() ? window()->effectiveDevicePixelRatio() : 1.0;
  const QSize pixels = (QSizeF(width(), height()) * dpr).toSize();
  if (!m_cacheValid || m_cache.size() != pixels) {
    m_cache = QImage(pixels, QImage::Format_ARGB32_Premultiplied);
    m_cache.setDevicePixelRatio(dpr);
    m_cache.fill(Qt::transparent);
    QPainter p(&m_cache);
    p.setRenderHint(QPainter::Antialiasing);
    p.translate(0, -m_scroll);
    const qreal top = m_scroll / u - 20, bottom = (m_scroll + height()) / u + 20;
    for (const Stroke &s : m_strokes) {
      const auto [lo, hi] = std::minmax_element(s.pts.begin(), s.pts.end(),
                                                [](QPointF a, QPointF b) { return a.y() < b.y(); });
      if (hi->y() >= top && lo->y() <= bottom)
        drawStroke(p, s, u);
    }
    m_cacheValid = true;
  }
  painter->drawImage(QPointF(0, 0), m_cache);
  if (!m_live.pts.isEmpty()) {
    painter->translate(0, -m_scroll);
    drawStroke(*painter, m_live, u);
  }
}

void InkCanvas::setError(const QString &error) {
  if (error == m_error)
    return;
  m_error = error;
  emit errorChanged();
}

QByteArray InkCanvas::toSvg(const QVector<Stroke> &strokes, const QColor &ink) {
  qreal bottom = 0;
  for (const Stroke &s : strokes)
    for (const QPointF &pt : s.pts)
      bottom = qMax(bottom, pt.y());
  const int h = int(std::ceil(bottom + Margin));
  QString out = QStringLiteral(
                    "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"%1\" height=\"%2\" viewBox=\"0 0 %1 %2\" "
                    "data-blloku=\"1\">\n")
                    .arg(int(PageWidth))
                    .arg(h);
  for (const Stroke &s : strokes) {
    QStringList d, p;
    float sum = 0;
    for (qsizetype i = 0; i < s.pts.size(); ++i) {
      d.append(QStringLiteral("%1%2 %3")
                   .arg(i ? QLatin1Char('L') : QLatin1Char('M'))
                   .arg(s.pts[i].x(), 0, 'f', 1)
                   .arg(s.pts[i].y(), 0, 'f', 1));
      p.append(QString::number(s.p[i], 'f', 2));
      sum += s.p[i];
    }
    out += QStringLiteral("  <path d=\"%1\" fill=\"none\" stroke=\"%2\" stroke-width=\"%3\" "
                          "stroke-linecap=\"round\" stroke-linejoin=\"round\" data-p=\"%4\"/>\n")
               .arg(d.join(QLatin1Char(' ')), ink.name())
               .arg(strokeWidth(s.pts.isEmpty() ? 0 : sum / s.pts.size()), 0, 'f', 2)
               .arg(p.join(QLatin1Char(' ')));
  }
  out += QStringLiteral("</svg>\n");
  return out.toUtf8();
}

bool InkCanvas::fromSvg(const QByteArray &svg, QVector<Stroke> *strokes) {
  static const QRegularExpression number(QStringLiteral(R"(-?\d+(?:\.\d+)?)"));
  QXmlStreamReader xml(svg);
  bool sawSvg = false;
  while (!xml.atEnd()) {
    if (!xml.readNextStartElement())
      continue;
    const auto attrs = xml.attributes();
    if (xml.name() == QLatin1String("svg")) {
      sawSvg = true;
    } else if (xml.name() == QLatin1String("path")) {
      Stroke s;
      QVector<qreal> xy;
      for (auto it = number.globalMatchView(attrs.value(QLatin1String("d"))); it.hasNext();)
        xy.append(it.next().captured().toDouble());
      for (qsizetype i = 0; i + 1 < xy.size(); i += 2)
        s.pts.append(QPointF(xy[i], xy[i + 1]));
      const QStringList p = attrs.value(QLatin1String("data-p")).toString().split(QLatin1Char(' '), Qt::SkipEmptyParts);
      for (qsizetype i = 0; i < s.pts.size(); ++i)
        s.p.append(i < p.size() ? p[i].toFloat() : 0.0f);
      if (!s.pts.isEmpty())
        strokes->append(s);
    }
  }
  return sawSvg && !xml.hasError();
}
