// Qt on Wayland never turns an unhandled pen press into a mouse click: its
// Wayland platform code leaves TabletEvent::platformSynthesizesMouse at the
// default (true), so mouse-only items such as MouseArea ignore the pen.
// Preloaded into a Qt program, this sets it to false, then takes itself out of
// LD_PRELOAD so the programs it starts don't load it. Outside Qt it does nothing.

#define _GNU_SOURCE
#include <dlfcn.h>
#include <stdbool.h>
#include <stdlib.h>
#include <string.h>

__attribute__((constructor)) static void pen_click(void) {
  void (*set)(bool) = (void (*)(bool))dlsym(RTLD_DEFAULT,
      "_ZN29QWindowSystemInterfacePrivate11TabletEvent27setPlatformSynthesizesMouseEb");
  if (!set)
    return;
  set(false);

  const char *preload = getenv("LD_PRELOAD");
  if (preload && strstr(preload, "libmidhat-pen-click.so") && !strpbrk(preload, ": "))
    unsetenv("LD_PRELOAD");
}
