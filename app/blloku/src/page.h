#pragma once

#include "blocks.h"

#include <QDateTime>
#include <QObject>
#include <QTimer>
#include <QVariantList>

class Page : public QObject {
  Q_OBJECT
  Q_PROPERTY(QString path READ path CONSTANT)
  Q_PROPERTY(QString bllok READ bllok CONSTANT)
  Q_PROPERTY(QString title READ title CONSTANT)
  Q_PROPERTY(QVariantList blocks READ blocks NOTIFY blocksChanged)
  Q_PROPERTY(QString error READ error NOTIFY errorChanged)
  Q_PROPERTY(QVariantList answers READ answers NOTIFY answersChanged)
  Q_PROPERTY(double rate READ rate WRITE setRate NOTIFY answersChanged)
  Q_PROPERTY(double pageRate READ pageRate NOTIFY answersChanged)

public:
  Page(const QString &path, const QString &fresh, const QString &title, QObject *parent = nullptr);
  ~Page() override { saveNow(); }

  QString path() const { return m_path; }
  QString bllok() const;
  QString title() const { return m_title; }
  QVariantList blocks() const;
  QString error() const { return m_error; }
  QVariantList answers() const { return m_answers; }
  double rate() const { return m_rate; }
  void setRate(double rate);
  double pageRate() const { return m_pageRate; }

  Q_INVOKABLE void setBlockText(int index, const QString &text);
  Q_INVOKABLE QString inkFile(int index) const;
  Q_INVOKABLE QString newInkFile() const;
  Q_INVOKABLE void appendInk(const QString &file);
  Q_INVOKABLE void appendText(const QString &text);
  Q_INVOKABLE QString layerFile() const;
  Q_INVOKABLE void ensureLayer();
  Q_INVOKABLE void saveNow();
  Q_INVOKABLE int insertCalc(int index, int cursor);
  Q_INVOKABLE int removeBlock(int index);

signals:
  void blocksChanged();
  void errorChanged();
  void answersChanged();

private:
  void setError(const QString &error);
  void recalc();

  QString m_path;
  QString m_savePath;
  QString m_title;
  QList<Block> m_blocks;
  QDateTime m_diskTime;
  QTimer m_timer;
  bool m_dirty = false;
  QString m_error;
  QVariantList m_answers;
  double m_rate = 0;
  double m_pageRate = 0;
};
