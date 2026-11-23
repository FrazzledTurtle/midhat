import QtQuick
import Quickshell.Wayland
import qs.Commons
import qs.Ui

// One big Slate rail button. Lit (an inverted tile) while what it opens is in
// front: nothing for Home, a reader for Read, Blloku for Write, the agent card,
// OSKar, the menu.
BarWidget {
  id: root
  moduleName: "midhat.slate-button"

  readonly property var actions: ({
    home: { glyph: "󰚡", label: "Home", command: "hyprctl dispatch 'hl.dsp.focus({ workspace = \"empty\" })'" },
    read: { glyph: "󱗖", label: "Read", command: "midhat-launch-or-focus rocks.koreader.KOReader koreader" },
    write: { glyph: "󰲶", label: "Write", command: "midhat-launch-or-focus org.midhat.Blloku 'uwsm-app -- blloku'" },
    ask: { glyph: "󰍪", label: "Ask Agent", command: "midhat-agent-card" },
    keyboard: { glyph: "󰥻", label: "Keyboard", command: "midhat-shell shell toggle io.github.vladkarok.oskar" },
    settings: { glyph: "󰘮", label: "Settings", command: "midhat-menu toggle settings" }
  })
  readonly property string action: actions[String(setting("action", ""))] ? String(setting("action", "")) : "home"
  readonly property var spec: actions[action]
  readonly property string appId: ToplevelManager.activeToplevel ? String(ToplevelManager.activeToplevel.appId || "") : ""
  readonly property var host: bar ? bar.shell : null
  readonly property bool lit: {
    switch (action) {
    case "home": return appId === ""
    case "read": return appId === "rocks.koreader.KOReader" || appId === "org.pwmt.zathura"
    case "write": return appId === "org.midhat.Blloku"
    case "ask": return appId === "org.midhat.agent"
    case "keyboard": return !!host && host.isPluginOpen("io.github.vladkarok.oskar")
    case "settings": return !!host && host.isPluginOpen("midhat.menu")
    }
    return false
  }

  implicitWidth: barSize
  implicitHeight: Style.bar.iconSlot + 8

  Rectangle {
    anchors.centerIn: parent
    width: Style.bar.iconSlot
    height: Style.bar.iconSlot
    radius: 14
    color: root.lit && root.bar ? root.bar.barForeground : "transparent"
  }

  BarIconButton {
    anchors.fill: parent
    bar: root.bar
    text: root.spec.glyph
    useActiveColor: false
    foreground: root.lit && root.bar ? root.bar.background : (root.bar ? root.bar.barForeground : "black")
    tooltipText: root.spec.label
    onPressed: function(button) {
      if (root.bar) root.bar.run(root.spec.command)
    }
  }
}
