#pragma once

#include <QHash>
#include <QList>
#include <QString>

// Evaluates a page's calc lines top to bottom. Names and the € rate carry on
// down the page. An answer is "" for blank and # lines, "? why" when it fails.
class Calc {
public:
  enum Unit { None, Lek, Eur };
  struct Value {
    double v = 0;
    Unit unit = None;
    bool percent = false;
  };

  explicit Calc(double rate = 0) : m_rate(rate) {}
  QString line(const QString &source);
  double rate() const { return m_rate; }
  bool rateSet() const { return m_rateSet; }

private:
  struct Tok {
    enum Kind { Num, Name, Money, Op, End } kind = End;
    double num = 0;
    QString text;
    Unit unit = None;
  };

  bool tokenize(const QString &s);
  const Tok &peek(int ahead = 0) const;
  bool takeOp(const QString &op);
  bool takeWord(const QString &word);
  void fail(const QString &why);

  Value expr();
  Value term();
  Value unary();
  Value power();
  Value postfix();
  Value primary();
  Value convert(Value v, Unit to);
  Value add(Value l, Value r, double sign);
  QString format(const Value &v) const;

  double m_rate;
  bool m_rateSet = false;
  QHash<QString, Value> m_names;
  QList<Tok> m_toks;
  int m_at = 0;
  QString m_error;
};
