#include "calc.h"

#include <cstdio>

static int failures = 0;

static void is(Calc &calc, const char *line, const char *want) {
  const QString got = calc.line(QString::fromUtf8(line));
  const bool ok = got == QString::fromUtf8(want);
  std::printf("%s - %s => %s%s%s\n", ok ? "ok" : "not ok", line, qPrintable(got), ok ? "" : " want ", ok ? "" : want);
  if (!ok)
    ++failures;
}

static void fails(Calc &calc, const char *line) {
  const QString got = calc.line(QString::fromUtf8(line));
  const bool ok = got.startsWith(QLatin1String("? "));
  std::printf("%s - %s fails (%s)\n", ok ? "ok" : "not ok", line, qPrintable(got));
  if (!ok)
    ++failures;
}

int main() {
  {
    Calc c;
    is(c, "", "");
    is(c, "# groceries", "");
    is(c, "2 + 3 * 4", "14");
    is(c, "(2 + 3) * 4", "20");
    is(c, "2 ^ 3 ^ 2", "512");
    is(c, "-2 ^ 2", "-4");
    is(c, "2 ^ -1", "0.5");
    is(c, "1 / 3", "0.333333");
    is(c, "7 × 6 ÷ 2 − 1", "20");
    is(c, "2,5 * 2", "5");
    is(c, "4,500 / 3", "1500");
    is(c, "1,234,567 + 1", "1234568");
    fails(c, "1 / 0");
    fails(c, "2 3");
    fails(c, "2 $ 3");
    fails(c, "(2 + 3");
    fails(c, "rent * 2");
    fails(c, "2 +");
  }
  {
    Calc c;
    is(c, "room = 4500 lek / 3", "1500 lek");
    is(c, "room * 2", "3000 lek");
    is(c, "x = 2", "2");
    is(c, "x = x + 1", "3");
    is(c, "x", "3");
    is(c, "4500lek + 500", "5000 lek");
    fails(c, "5 lek * 2 lek");
    fails(c, "10 / 2 lek");
    is(c, "3000 lek / 1500 lek", "2");
  }
  {
    Calc c;
    is(c, "15%", "15%");
    is(c, "4500 + 10%", "4950");
    is(c, "4500 lek - 20%", "3600 lek");
    is(c, "10% of 4500 lek", "450 lek");
    is(c, "20% + 5%", "25%");
    is(c, "200 * 10%", "20");
  }
  {
    Calc c;
    fails(c, "5 € in lek");
    is(c, "€15 / 3", "5 €");
    is(c, "5 in €", "5 €");
    is(c, "€ = 98 lek", "€1 = 98 lek");
    if (!(c.rateSet() && c.rate() == 98)) {
      std::printf("not ok - rate line sets the rate\n");
      ++failures;
    }
    is(c, "100 € in lek", "9800 lek");
    is(c, "4900 lek to eur", "50 €");
    is(c, "10 € + 980 lek", "20 €");
    is(c, "980 lek + 10 €", "1960 lek");
    is(c, "1 eur = 100 lek", "€1 = 100 lek");
    is(c, "2 € in lek", "200 lek");
    fails(c, "€ = 98");
    fails(c, "5 in kg");
  }
  {
    Calc c(97.5);
    is(c, "10 € in lek", "975 lek");
    if (c.rateSet()) {
      std::printf("not ok - a given rate isn't one the page set\n");
      ++failures;
    }
  }
  return failures == 0 ? 0 : 1;
}
