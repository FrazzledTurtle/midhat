#include "calc.h"

#include <QStringList>
#include <cmath>

static Calc::Unit unitWord(const QString &w) {
  static const QStringList lek{QStringLiteral("lek"), QStringLiteral("leke"), QStringLiteral("lekë")};
  static const QStringList eur{QStringLiteral("eur"), QStringLiteral("euro"), QStringLiteral("euros")};
  const QString l = w.toLower();
  return lek.contains(l) ? Calc::Lek : eur.contains(l) ? Calc::Eur : Calc::None;
}

static bool keyword(const QString &w) {
  return w == QLatin1String("of") || w == QLatin1String("in") || w == QLatin1String("to");
}

static QString number(double v, int decimals) {
  QString s = QString::number(v, 'f', decimals);
  if (s.contains(QLatin1Char('.'))) {
    while (s.endsWith(QLatin1Char('0')))
      s.chop(1);
    if (s.endsWith(QLatin1Char('.')))
      s.chop(1);
  }
  return s == QLatin1String("-0") ? QStringLiteral("0") : s;
}

bool Calc::tokenize(const QString &s) {
  m_toks.clear();
  m_at = 0;
  for (qsizetype i = 0; i < s.size();) {
    const QChar c = s[i];
    if (c.isSpace()) {
      ++i;
    } else if (c.isDigit() || (c == QLatin1Char('.') && i + 1 < s.size() && s[i + 1].isDigit())) {
      // Decimals with . or ,; a comma before exactly three digits groups thousands (4,500).
      QString digits;
      bool decimal = false;
      while (i < s.size()) {
        const QChar d = s[i];
        if (d.isDigit()) {
          digits += d;
          ++i;
        } else if (d == QLatin1Char(',') && !decimal && i + 3 < s.size() &&
                   s[i + 1].isDigit() && s[i + 2].isDigit() && s[i + 3].isDigit() &&
                   (i + 4 >= s.size() || !s[i + 4].isDigit())) {
          ++i;
        } else if ((d == QLatin1Char('.') || d == QLatin1Char(',')) && !decimal && i + 1 < s.size() && s[i + 1].isDigit()) {
          digits += QLatin1Char('.');
          decimal = true;
          ++i;
        } else {
          break;
        }
      }
      m_toks.append({Tok::Num, digits.toDouble()});
    } else if (c == QChar(0x20AC)) {
      m_toks.append({Tok::Money, 0, QString(c), Eur});
      ++i;
    } else if (c.isLetter() || c == QLatin1Char('_')) {
      const qsizetype from = i;
      while (i < s.size() && (s[i].isLetterOrNumber() || s[i] == QLatin1Char('_')))
        ++i;
      const QString word = s.mid(from, i - from);
      const Unit u = unitWord(word);
      m_toks.append({u == None ? Tok::Name : Tok::Money, 0, word, u});
    } else if (QStringLiteral("+-*/^()%=").contains(c)) {
      m_toks.append({Tok::Op, 0, QString(c)});
      ++i;
    } else if (c == QChar(0x00D7)) {
      m_toks.append({Tok::Op, 0, QStringLiteral("*")});
      ++i;
    } else if (c == QChar(0x00F7)) {
      m_toks.append({Tok::Op, 0, QStringLiteral("/")});
      ++i;
    } else if (c == QChar(0x2212)) {
      m_toks.append({Tok::Op, 0, QStringLiteral("-")});
      ++i;
    } else {
      fail(QStringLiteral("what is %1?").arg(c));
      return false;
    }
  }
  m_toks.append(Tok{});
  return true;
}

const Calc::Tok &Calc::peek(int ahead) const {
  return m_toks[qMin(m_at + ahead, int(m_toks.size()) - 1)];
}

bool Calc::takeOp(const QString &op) {
  if (peek().kind == Tok::Op && peek().text == op) {
    ++m_at;
    return true;
  }
  return false;
}

bool Calc::takeWord(const QString &word) {
  if (peek().kind == Tok::Name && peek().text == word) {
    ++m_at;
    return true;
  }
  return false;
}

void Calc::fail(const QString &why) {
  if (m_error.isEmpty())
    m_error = why;
}

Calc::Value Calc::convert(Value v, Unit to) {
  if (v.unit == to || to == None)
    return v;
  if (v.unit == None) {
    v.unit = to;
    return v;
  }
  if (m_rate <= 0) {
    fail(QStringLiteral("set a rate: € = … lek"));
    return v;
  }
  v.v = to == Eur ? v.v / m_rate : v.v * m_rate;
  v.unit = to;
  return v;
}

Calc::Value Calc::add(Value l, Value r, double sign) {
  if (r.percent && !l.percent) {
    l.v *= 1 + sign * r.v;
    return l;
  }
  if (l.unit == None)
    l.unit = r.unit;
  r = convert(r, l.unit);
  l.v += sign * r.v;
  return l;
}

Calc::Value Calc::expr() {
  Value l = term();
  for (;;) {
    if (takeOp(QStringLiteral("+")))
      l = add(l, term(), 1);
    else if (takeOp(QStringLiteral("-")))
      l = add(l, term(), -1);
    else
      return l;
  }
}

Calc::Value Calc::term() {
  Value l = unary();
  for (;;) {
    if (takeOp(QStringLiteral("*"))) {
      const Value r = unary();
      if (l.unit != None && r.unit != None)
        fail(QStringLiteral("can't multiply money by money"));
      l = {l.v * r.v, l.unit != None ? l.unit : r.unit, l.percent && r.percent};
    } else if (takeOp(QStringLiteral("/"))) {
      Value r = unary();
      if (r.v == 0) {
        fail(QStringLiteral("÷ 0"));
        return l;
      }
      if (r.unit != None && l.unit == None)
        fail(QStringLiteral("can't divide by money"));
      if (l.unit != None && r.unit != None) {
        r = convert(r, l.unit);
        l = {l.v / r.v, None};
      } else {
        l = {l.v / r.v, l.unit};
      }
    } else {
      return l;
    }
  }
}

Calc::Value Calc::unary() {
  if (takeOp(QStringLiteral("-"))) {
    Value v = unary();
    v.v = -v.v;
    return v;
  }
  if (takeOp(QStringLiteral("+")))
    return unary();
  return power();
}

Calc::Value Calc::power() {
  Value base = postfix();
  if (takeOp(QStringLiteral("^"))) {
    const Value e = unary();
    if (base.unit != None || e.unit != None)
      fail(QStringLiteral("can't raise money to a power"));
    base = {std::pow(base.v, e.v), None};
  }
  return base;
}

Calc::Value Calc::postfix() {
  Value v = primary();
  if (takeOp(QStringLiteral("%"))) {
    if (v.unit != None)
      fail(QStringLiteral("a percent of money?"));
    v = {v.v / 100, None, true};
    if (takeWord(QStringLiteral("of"))) {
      Value of = unary();
      of.v *= v.v;
      return of;
    }
  }
  return v;
}

Calc::Value Calc::primary() {
  const Tok t = peek();
  if (t.kind == Tok::Num) {
    ++m_at;
    Value v{t.num};
    if (peek().kind == Tok::Money) {
      v.unit = peek().unit;
      ++m_at;
    }
    return v;
  }
  if (t.kind == Tok::Money && peek(1).kind == Tok::Num) {
    m_at += 2;
    return {peek(-1).num, t.unit};
  }
  if (takeOp(QStringLiteral("("))) {
    const Value v = expr();
    if (!takeOp(QStringLiteral(")")))
      fail(QStringLiteral("missing )"));
    return v;
  }
  if (t.kind == Tok::Name && !keyword(t.text)) {
    ++m_at;
    if (!m_names.contains(t.text))
      fail(QStringLiteral("what is %1?").arg(t.text));
    return m_names.value(t.text);
  }
  fail(t.kind == Tok::End ? QStringLiteral("unfinished") : QStringLiteral("didn't expect %1").arg(t.text));
  return {};
}

QString Calc::format(const Value &v) const {
  if (v.percent)
    return number(v.v * 100, 2) + QLatin1Char('%');
  if (v.unit == Lek)
    return number(v.v, 2) + QStringLiteral(" lek");
  if (v.unit == Eur)
    return number(v.v, 2) + QStringLiteral(" €");
  return number(v.v, 6);
}

QString Calc::line(const QString &source) {
  const QString s = source.trimmed();
  if (s.isEmpty() || s.startsWith(QLatin1Char('#')))
    return QString();
  m_error.clear();
  if (!tokenize(s))
    return QStringLiteral("? ") + m_error;

  // "€ = 98 lek" or "1 eur = 98 lek" sets the rate for the lines below.
  double per = 1;
  if (peek().kind == Tok::Num && peek(1).kind == Tok::Money && peek(1).unit == Eur && peek(2).text == QLatin1String("=")) {
    per = peek().num;
    ++m_at;
  }
  if (peek().kind == Tok::Money && peek().unit == Eur && peek(1).kind == Tok::Op && peek(1).text == QLatin1String("=")) {
    m_at += 2;
    const Value v = expr();
    if (peek().kind != Tok::End)
      fail(QStringLiteral("didn't expect %1").arg(peek().text));
    if (m_error.isEmpty() && (v.unit != Lek || v.v <= 0 || per <= 0))
      fail(QStringLiteral("a rate looks like € = 98 lek"));
    if (!m_error.isEmpty())
      return QStringLiteral("? ") + m_error;
    m_rate = v.v / per;
    m_rateSet = true;
    return QStringLiteral("€1 = ") + format({m_rate, Lek});
  }

  QString name;
  if (peek().kind == Tok::Name && !keyword(peek().text) && peek(1).kind == Tok::Op && peek(1).text == QLatin1String("=")) {
    name = peek().text;
    m_at += 2;
  }
  Value v = expr();
  if (takeWord(QStringLiteral("in")) || takeWord(QStringLiteral("to"))) {
    if (peek().kind == Tok::Money) {
      v = convert(v, peek().unit);
      v.percent = false;
      ++m_at;
    } else {
      fail(QStringLiteral("in lek or in €?"));
    }
  }
  if (peek().kind != Tok::End)
    fail(QStringLiteral("didn't expect %1").arg(peek().text));
  if (m_error.isEmpty() && !std::isfinite(v.v))
    fail(QStringLiteral("too big"));
  if (!m_error.isEmpty())
    return QStringLiteral("? ") + m_error;
  if (!name.isEmpty())
    m_names.insert(name, v);
  return format(v);
}
