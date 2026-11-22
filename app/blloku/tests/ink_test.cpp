#include "ink.h"

#include <QFile>
#include <QGuiApplication>
#include <QTemporaryDir>
#include <cmath>
#include <cstdio>

static int failures = 0;

static void check(bool ok, const char *what) {
  std::printf("%s - %s\n", ok ? "ok" : "not ok", what);
  if (!ok)
    ++failures;
}

static QVector<QPointF> firstPoints(const QVector<InkCanvas::Stroke> &strokes) {
  QVector<QPointF> out;
  for (const auto &s : strokes)
    out.append(s.pts.first());
  return out;
}

int main(int argc, char *argv[]) {
  qputenv("QT_QPA_PLATFORM", "offscreen");
  QGuiApplication app(argc, argv);

  {
    QVector<InkCanvas::Stroke> in{{{QPointF(10, 20), QPointF(30.04, 40.26)}, {0.25f, 0.5f}},
                                  {{QPointF(5, 5)}, {0.0f}}};
    QVector<InkCanvas::Stroke> out;
    check(InkCanvas::fromSvg(InkCanvas::toSvg(in, Qt::black), &out), "our SVG reads back");
    bool same = out.size() == 2 && out[0].pts.size() == 2 && out[1].pts.size() == 1;
    for (int i = 0; same && i < 2; ++i)
      for (int k = 0; k < in[i].pts.size(); ++k)
        same = std::abs(out[i].pts[k].x() - in[i].pts[k].x()) < 0.06 &&
               std::abs(out[i].pts[k].y() - in[i].pts[k].y()) < 0.06 && std::abs(out[i].p[k] - in[i].p[k]) < 0.006;
    check(same, "strokes, points and pressure survive the round trip");
  }

  {
    QVector<InkCanvas::Stroke> out;
    check(InkCanvas::fromSvg("<svg xmlns=\"http://www.w3.org/2000/svg\"><path d=\"M1 2 L3 4\"/></svg>", &out) &&
              out.size() == 1 && out[0].p == QVector<float>{0, 0},
          "a plain SVG path reads with no pressure");
    check(!InkCanvas::fromSvg("not svg at all", &out), "a broken file is refused");
  }

  {
    QTemporaryDir tmp;
    const QString file = tmp.filePath(QStringLiteral("page.ink/1.svg"));
    InkCanvas canvas;
    canvas.setWidth(InkCanvas::PageWidth);
    canvas.setHeight(400);
    for (int i = 0; i < 3; ++i) {
      canvas.begin(10 + 100 * i, 50, 0.3);
      canvas.extend(60 + 100 * i, 50, 0.4);
      canvas.finish();
    }
    canvas.eraseAt(135, 50);
    canvas.eraseAt(35, 50);
    canvas.endErase();
    check(canvas.saveAs(file) && QFile::exists(file), "a canvas saves to its file");

    InkCanvas reopened;
    reopened.setWidth(InkCanvas::PageWidth);
    reopened.setSource(file);
    check(!reopened.empty() && reopened.contentHeight() > 50, "the saved ink opens again");

    check(canvas.undo(), "undo after an erase");
    canvas.saveAs(file);
    QVector<InkCanvas::Stroke> strokes;
    QFile f(file);
    check(f.open(QIODevice::ReadOnly) && InkCanvas::fromSvg(f.readAll(), &strokes) &&
              firstPoints(strokes) == QVector<QPointF>{QPointF(10, 50), QPointF(110, 50), QPointF(210, 50)},
          "undoing an erase puts every stroke back in its place");
    check(canvas.undo() && canvas.undo() && canvas.undo() && canvas.empty() && !canvas.undo(),
          "undo walks back every stroke, then stops");
  }

  {
    QTemporaryDir tmp;
    const QString file = tmp.filePath(QStringLiteral("page.svg"));
    const QByteArray original = "<svg xmlns=\"http://www.w3.org/2000/svg\" data-paper=\"lined\">"
                                "<path d=\"M1 2 L3 4\" data-p=\"0.5 0.5\"/></svg>";
    QFile f(file);
    if (f.open(QIODevice::WriteOnly))
      f.write(original);
    f.close();
    {
      InkCanvas canvas;
      canvas.setWidth(InkCanvas::PageWidth);
      canvas.setHeight(300);
      canvas.setSource(file);
      canvas.setScroll(120);
    }
    QFile g(file);
    check(g.open(QIODevice::ReadOnly) && g.readAll() == original, "opening and scrolling a page never writes it");
  }

  {
    InkCanvas canvas;
    canvas.setWidth(InkCanvas::PageWidth);
    canvas.setHeight(300);
    canvas.setScroll(1000);
    canvas.begin(10, 20, 0.5);
    canvas.extend(30, 20, 0.5);
    canvas.finish();
    check(std::abs(canvas.contentHeight() - (1020 + 80)) < 0.5, "strokes land at their place on the page, not on screen");
    canvas.eraseAt(20, 20);
    canvas.endErase();
    check(canvas.empty(), "erasing finds strokes through the scroll too");
  }

  {
    QTemporaryDir tmp;
    const QString file = tmp.filePath(QStringLiteral("bad.svg"));
    QFile f(file);
    if (f.open(QIODevice::WriteOnly))
      f.write("garbage");
    f.close();
    InkCanvas canvas;
    canvas.setWidth(InkCanvas::PageWidth);
    canvas.setSource(file);
    canvas.begin(1, 1, 0.5);
    canvas.finish();
    canvas.saveAs(file);
    QFile g(file);
    check(g.open(QIODevice::ReadOnly) && g.readAll() == "garbage" && !canvas.error().isEmpty(),
          "an unreadable ink file is never written over");
  }

  return failures ? 1 : 0;
}
