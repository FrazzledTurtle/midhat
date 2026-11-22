#pragma once

#include <QDate>
#include <QObject>
#include <QString>

#include "page.h"

// The notebooks (blloqe) under ~/Blloku: one folder each, one .md file per page.
class Library : public QObject {
  Q_OBJECT
  Q_PROPERTY(QString root READ root CONSTANT)

public:
  explicit Library(const QString &root, QObject *parent = nullptr);

  QString root() const { return m_root; }

  Q_INVOKABLE QVariantList blloqe() const;
  Q_INVOKABLE QVariantList pages(const QString &bllok) const;
  Q_INVOKABLE QString todayFile(QDate day = QDate::currentDate()) const;
  Q_INVOKABLE QString newPageFile(const QString &bllok) const;
  Q_INVOKABLE QString newBllok(const QString &name) const;
  // Saves and drops the page open before; Library owns the one it returns.
  Q_INVOKABLE Page *open(const QString &file);

  static QString titleFor(const QString &file);

private:
  QString m_root;
  Page *m_current = nullptr;
};
