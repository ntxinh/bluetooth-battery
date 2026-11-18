# AGENTS.md

A DankMaterialShell (DMS) DankBar widget plugin: battery percentage of connected
Bluetooth peripherals, read from UPower through Quickshell. QML only — no build
step, no test framework, no package manager.

## Layout

| File | Responsibility |
|---|---|
| `plugin.json` | DMS manifest (`id: bluetoothBattery`, `type: widget`) |
| `BatteryModel.qml` | Only place that touches UPower: filters, normalises, sorts |
| `BluetoothBatteryWidget.qml` | `PluginComponent`: horizontal/vertical pills and the popout |
| `BluetoothBatterySettings.qml` | `PluginSettings`: display mode, pin, thresholds |
| `DESIGN.md` | Design decisions and verified API facts |
| `docs/superpowers/plans/` | Implementation plan this repo followed |
| `Makefile` / `mise.toml` | install, uninstall, reload, status, check, logs |

## Commands

```bash
make install     # symlink repo -> ~/.config/DankMaterialShell/plugins/BluetoothBattery
make reload      # dms ipc call plugins reload bluetoothBattery
make status      # is it loaded?
make check       # plugin.json parses; qmllint only if installed (it is not here)
make logs        # journalctl --user -u dms -f
```

`mise run <task>` mirrors the same targets.

## Verified API facts (DMS 1.4.4, Quickshell on Fedora 44)

Read the installed sources before trusting memory:
`/usr/share/quickshell/dms/` (Modules/Plugins, Widgets, Common/Theme.qml,
Services/BatteryService.qml) and
`/usr/lib64/qt6/qml/Quickshell/Services/UPower/`.

- `UPower.devices` is a list model whose only usable property here is
  **`values`** (an array). It is empty for the first ~1 s of the shell's life;
  `count`/`get(i)` are **not** available in this build even though DMS's own
  `BatteryService` calls them.
- `UPowerDevice.percentage` is **0.0–1.0**. `percentage == 0` means "no report
  yet", not "empty".
- Useful `UPowerDevice` fields: `nativePath`, `model`, `type`, `state`,
  `isPresent`, `ready`, `isLaptopBattery`, `powerSupply`.
- `PluginComponent` (root of the widget) injects `axis`, `section`,
  `parentScreen`, `widgetThickness`, `barThickness`, `pluginData`,
  `pluginService`, and offers `setVisibilityOverride(bool)` — the only supported
  way to collapse a pill to zero width. Do not define `Component.onCompleted` in
  the widget: it shadows the base component's own handler.
- `popoutContent: Component { PopoutComponent { ... } }`; `popoutHeight: 0`
  auto-sizes from content. The popout is instantiated on first click, so its
  errors only appear in the journal then.
- `pluginData` reloads on settings changes; nested components (`SelectionSetting`
  etc.) require the `settings_write` permission or the settings UI is replaced
  by an error message.
- Settings keys in use: `displayMode`, `pinnedDevice`, `showName`,
  `warnThreshold`, `criticalThreshold`, `hideWhenEmpty`. Adding `pollInterval`
  back only makes sense with the BlueZ fallback.
- `qs.*` imports resolve only inside the running shell; a standalone
  `quickshell --path` config cannot import them. `BatteryModel.qml` therefore
  imports only `QtQuick` + `Quickshell.Services.UPower` so it can be tested in
  isolation.

## Conventions

- 4-space indent, double quotes, `Theme.*` tokens for colour, spacing and font
  size; `DankIcon`/`StyledText` over raw `Text`.
- No `Timer`, `Process` or polling. Everything reacts to UPower property
  changes.
- All device filtering lives in `BatteryModel.qml`; the widget and settings only
  render it.
- Icon names from Material Symbols Rounded: `mouse`, `keyboard`, `headphones`,
  `bluetooth`, `bolt`.

## Verifying a change

1. `make check` — manifest still valid.
2. `make reload` then `journalctl --user -u dms --since "-2min" | grep -i bluetoothbattery`
   — expect `Plugin loaded: bluetoothBattery` and no QML errors.
3. Pills only instantiate when the plugin is placed in a bar config, and the
   popout only when clicked. To test `BatteryModel` alone, point a throwaway
   Quickshell config at it:

   ```qml
   ShellRoot {
       BatteryModel { id: battery }
       Timer { interval: 3000; running: true; onTriggered: {
           console.warn("PROBE " + JSON.stringify(battery.devices)); } }
   }
   ```

   Symlink `BatteryModel.qml` next to that `shell.qml`, run
   `WAYLAND_DISPLAY=wayland-1 quickshell --path <dir>`, and read the `qml:` lines.
