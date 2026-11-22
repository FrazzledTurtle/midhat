#include "library.h"
#include "page.h"

#include <QDir>
#include <QFile>
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QRegularExpression>
#include <QVariantMap>

#include <dlfcn.h>

// shortcut: read once at start, so a theme switch shows on the next launch; watch the file when that matters.
static QVariantMap readTheme() {
  QVariantMap colors{{QStringLiteral("background"), QStringLiteral("#e4e4e4")},
                     {QStringLiteral("foreground"), QStringLiteral("#111111")},
                     {QStringLiteral("muted"), QStringLiteral("#686868")},
                     {QStringLiteral("selection"), QStringLiteral("#bdbdbd")},
                     {QStringLiteral("dark_background"), QStringLiteral("#d9d9d9")}};
  QFile file(QDir::home().filePath(QStringLiteral(".local/state/midhat/current/theme/colors.toml")));
  if (!file.open(QIODevice::ReadOnly))
    return colors;
  static const QRegularExpression line(QStringLiteral(R"(^\s*(\w+)\s*=\s*"(#[0-9a-fA-F]{6})\"\s*$)"));
  for (const QString &l : QString::fromUtf8(file.readAll()).split(QLatin1Char('\n')))
    if (const auto m = line.match(l); m.hasMatch() && colors.contains(m.captured(1)))
      colors[m.captured(1)] = m.captured(2);
  return colors;
}

int main(int argc, char *argv[]) {
  // Qt on Wayland never turns a pen tap into a click by itself; text editing needs it.
  // Looked up at run time like lib/pen-click.c, so a Qt update can't stop Blloku starting.
  if (auto set = reinterpret_cast<void (*)(bool)>(dlsym(
          RTLD_DEFAULT, "_ZN29QWindowSystemInterfacePrivate11TabletEvent27setPlatformSynthesizesMouseEb")))
    set(false);

  QGuiApplication app(argc, argv);
  QGuiApplication::setOrganizationName(QStringLiteral("midhat"));
  QGuiApplication::setApplicationName(QStringLiteral("Blloku"));
  QGuiApplication::setDesktopFileName(QStringLiteral("org.midhat.Blloku"));

  Library library(QDir::home().filePath(QStringLiteral("Blloku")));
  QStringList args = QGuiApplication::arguments().mid(1);
  const bool blloqe = args.removeAll(QStringLiteral("--blloqe")) > 0;
  Page *first = library.open(args.isEmpty() ? library.todayFile() : args.first());

  QQmlApplicationEngine engine;
  engine.setInitialProperties({{QStringLiteral("page"), QVariant::fromValue(first)},
                               {QStringLiteral("library"), QVariant::fromValue(&library)},
                               {QStringLiteral("theme"), readTheme()},
                               {QStringLiteral("view"), blloqe ? QStringLiteral("library") : QStringLiteral("page")}});
  engine.loadFromModule("Blloku", "Main");
  if (engine.rootObjects().isEmpty())
    return 1;
  return app.exec();
}
