# Bluetooth Battery — design

Status: approved 2026-11-18. Scope: M1–M3 plus M4's live connect/disconnect.

## Intent

A DankBar pill that answers one question at a glance: *how much battery does the
thing in my hand have?* Currently that number is only visible by opening DMS's
Control Center → Bluetooth detail, which is two clicks away and sits next to
devices you didn't ask about. The pill shows the lowest battery among connected
peripherals (mouse, keyboard, headset, …), turns warning/error colours at
thresholds, and a click lists every device with a per-device bar.

Nothing here pairs, connects or notifies. DMS owns pairing; this plugin only
reports what UPower already knows.

## Goals

- One glanceable pill, no clicks, that tracks battery changes reactively.
- Per-device breakdown in the popout, including charging state.
- Sensible defaults: warn 30%, critical 15%, hide when there's nothing to show.
- Settings for display mode (lowest / all / pinned), name display, thresholds,
  and empty-state behaviour.
- Zero polling. No `upower`/`bluetoothctl` subprocesses, no timers.

## Non-goals

- Pairing, connecting, disconnecting (DMS does this).
- Notifications (M5), Control Center tile (needs DMS ≥ 1.5; installed is 1.4.4),
  plugin-registry publishing (M5).
- **BlueZ `org.bluez.Battery1` fallback.** PRD §5 defers it to post-v1 and this
  round follows §5, not the M4 bullet. Live connect/disconnect *is* in scope.
- Non-Linux backends.

## Anti-goals

- A pill that lies. UPower reports `percentage: 0` before a device's first
  report; showing "0%" would look like a dead battery, so such devices are
  treated as "no data" and excluded.
- A pill that vanishes when you look at it: `hideWhenEmpty` only applies when
  there is genuinely no peripheral with a battery.
- UPower's hidpp object paths as identity. `hidpp_battery_1` renumbers.
- Re-implementing filtering in three places. One model, two views.

## Constraints (verified on this machine)

DMS `1.4.4-2.fc44`, Quickshell QML modules under `/usr/lib64/qt6/qml/Quickshell`,
`dms.service` running as a user unit, `make` and `mise` installed, no `qmllint`
or `qmlformat` on PATH.

UPower already exposes the target device:

```
/org/freedesktop/UPower/devices/battery_hidpp_battery_1
  native-path: hidpp_battery_1   model: MX Anywhere 3
  power supply: no   present: yes   rechargeable: yes
  state: discharging   percentage: 85%
```

Quickshell API actually shipped by this version (`import Quickshell.Services.UPower`):

- `UPower.devices` — reactive list (`.values`, `.count`, `.get(i)`); notifies.
- `UPowerDevice`: `type`, `powerSupply`, `percentage` (**0.0–1.0**), `isPresent`,
  `state`, `nativePath`, `model`, `ready`, `isLaptopBattery`, `changeRate`,
  `timeToEmpty`, `timeToFull`.
- `UPowerDeviceType.*`: `Mouse`, `Keyboard`, `Headset`, `Headphones`, `Speakers`,
  `OtherAudio`, `GamingInput`, `Phone`, `Tablet`, `Touchpad`, `Pen`, `Pda`,
  `Wearable`, `RemoteControl`, `Toy`, `BluetoothGeneric`, …
- `UPowerDeviceState.*`: `Unknown`, `Charging`, `Discharging`, `Empty`,
  `FullyCharged`, `PendingCharge`, `PendingDischarge`.

Plugin API (`qs.Modules.Plugins`, fields read from
`/usr/share/quickshell/dms/Modules/Plugins/`):

- `PluginComponent`: `horizontalBarPill`, `verticalBarPill` (Components),
  `popoutContent`, `popoutWidth`, `popoutHeight`, `pillClickAction`,
  `pluginData`, `pluginService`, `setVisibilityOverride(bool)`,
  `visibilityCommand`/`visibilityInterval`.
  Clicking the pill opens the popout automatically when `popoutContent` is set
  and `pillClickAction` is null.
- `PopoutComponent`: `headerText`, `detailsText`, `showCloseButton`; injects
  `closePopout`. `PluginPopout` overrides `popoutHeight` with the loaded
  content's `implicitHeight`, so `popoutHeight: 0` auto-sizes.
- Settings: `PluginSettings { pluginId }` plus `SelectionSetting`,
  `SliderSetting`, `ToggleSetting`, `StringSetting`, `ListSetting`, `ColorSetting`.
  `settings_write` permission is required or the UI shows an error.
- `pluginData` reloads on change; settings changes arrive via
  `pluginService.onPluginDataChanged`.
- Theme tokens used: `Theme.surfaceText`, `surfaceVariantText`, `outline`,
  `primary`, `warning`, `error`, `surfaceContainerHigh`, `fontSizeSmall`,
  `fontSizeMedium`, `spacingXS/S/M`.
- `qs.Services.BatteryService.bluetoothDevices` exists (name/percentage/type,
  used by DMS's CC Bluetooth detail) but is internal and insufficient — see C.

## Approaches

**A. Widget reads UPower directly.** One QML file; filter inline in the pill and
again in the popout, or hoist a property. Smallest, but filtering is the fiddly
part (type allow-list, exclusions, 0/unknown handling) and it gets duplicated;
the BlueZ fallback later would be surgery on the widget.

**B. `BatteryModel.qml` owns the data (chosen).** A `QtObject` exposes the
normalised `devices` array, `primaryDevice`, `kindOf()` and `colorFor()`. Widget
and popout both read it; settings instantiate it too, so the pinned-device
dropdown reuses the same filter. Matches PRD §9, keeps M4 a one-file change,
costs ~70 lines.

**C. Reuse `BatteryService.bluetoothDevices`.** ~15 lines, but DMS-internal,
name/percentage/type only: no id to pin on, no `state` for charging, narrower
type set than §5. Fails M3 and M4.

B was chosen; A digs a hole at M3/M4, C can't reach M3.

## Data model

`BatteryModel.qml`, a `QtObject` (one instance per widget instance; UPower is a
shared singleton so nothing is fetched twice):

```qml
readonly property var devices: [{
    id: "hidpp_battery_1",      // nativePath; only used as a pin tiebreak
    name: "MX Anywhere 3",      // model, falling back to the type name
    kind: "mouse",              // "mouse" | "keyboard" | "headset" | "other"
    percentage: 85,             // rounded 0–100
    charging: false,            // state === Charging
    connected: true             // isPresent && ready
}]
```

Inclusion rules, in order:

1. `dev.isPresent && dev.ready`
2. `!dev.isLaptopBattery && !dev.powerSupply` (the laptop battery, AC line power)
3. `dev.type` in the allow-list: `Mouse`, `Keyboard`, `Headset`, `Headphones`,
   `Speakers`, `OtherAudio`, `BluetoothGeneric`, `GamingInput`, `Phone`,
   `Tablet`, `Touchpad`, `Pen`, `Pda`, `Wearable`, `RemoteControl`, `Toy`.
   New/unknown UPower types stay out until added on purpose.
4. `Math.round(dev.percentage * 100) > 0`; unknown/absent charge is not "0%".

Kind mapping: `Mouse`→mouse, `Keyboard`→keyboard,
`Headset`/`Headphones`/`Speakers`/`OtherAudio`→headset, everything else→other.
Icons: `mouse`, `keyboard`, `headphones`, `bluetooth` (PRD §7.1).

Ordering: ascending percentage, so the device most likely to die is first — same
device the default pill shows. Ties keep UPower order.

`primaryDevice`:

- mode `lowest` (default): first device after sorting, `null` if none.
- mode `pinned`: the device whose `model` matches `pinnedDevice`
  case-insensitively (falling back to `nativePath` equality); if the pinned
  device is absent, fall back to `lowest` so the pill never goes blank because
  the mouse is asleep.
- mode `all`: unused; the pill renders the whole list.

Colour for a percentage (`colorFor(pct, charging)`):

- charging → `Theme.primary`
- `pct <= criticalThreshold` → `Theme.error`
- `pct <= warnThreshold` → `Theme.warning`
- otherwise → `Theme.surfaceText`

## UI

### Bar pill (horizontal)

```
[🖱] 85%            lowest / pinned, showName off
[🖱] MX Anywhere 3 85%
[⌨ 54%] [🖱 85%]    all mode, one group per device
```

`Row` inside `horizontalBarPill`, spacing `Theme.spacingXS`, `DankIcon` at
`Theme.iconSize - 6`, `StyledText` at `Theme.fontSizeMedium` in the threshold
colour. In `all` mode every device gets its own icon+`NN%` group; there is no
cap (one or two devices is the real case, and hiding devices would defeat the
mode). A charging device changes colour only — the bolt lives in the popout.

Hidden state: when `hideWhenEmpty` is true and `devices.length === 0`, call
`root.setVisibilityOverride(false)`; otherwise `(true)`. Reapplied from
`Component.onCompleted`, on `devices` change, and on `pluginData` change, since a
plugin reload rebuilds the component. Fallback if the override ever stops
collapsing the pill: bind the pill content's `implicitWidth: 0` when hidden.

With `hideWhenEmpty` off and nothing to show, the pill renders the `bluetooth`
icon plus `--` in `Theme.surfaceVariantText`, and still opens the popout with its
empty message. A missing UPower service behaves exactly like zero devices.

### Bar pill (vertical)

```
 🖱
 85%
```
Column, icon over `NN%`, `Theme.fontSizeSmall`; `all` mode stacks one icon+%
pair per device. Same colours and same hide rule.

### Popout

```
Bluetooth Devices                              [x]

[🖱] MX Anywhere 3        ▓▓▓▓▓▓▓░░░  85%
[⌨] Keychron K7  ⚡        ▓▓▓▓▓▓░░░░  60%

"No Bluetooth devices reporting battery"       (when empty)
```

`PopoutComponent { headerText: "Bluetooth Devices"; showCloseButton: true }`,
`popoutWidth: 380`, `popoutHeight: 0` (auto). The content is an inline
`Component` inside the widget root, so it reads the same `BatteryModel`
instance the pills do (QML keeps the enclosing scope). One `RowLayout` per device, width
`parent.width`: `DankIcon`, name (`StyledText`, elide right, `Layout.fillWidth`),
6 px rounded track (`Theme.outline`, opacity 0.35) with a fill proportional to
percentage in the threshold colour, `NN%`, and a `bolt` `DankIcon` when charging.
The empty state is a single `StyledText` in `surfaceVariantText`.

## Settings (`BluetoothBatterySettings.qml`)

| Key | Component | Default | Notes |
|---|---|---|---|
| displayMode | SelectionSetting | `lowest` | lowest / all / pinned |
| pinnedDevice | SelectionSetting | `""` | options = "None" + live `BatteryModel.devices` names; values are `model` strings |
| showName | ToggleSetting | false | name shown in the pill (lowest/pinned only) |
| warnThreshold | SliderSetting | 30 | warning colour at or below, 0–100 |
| criticalThreshold | SliderSetting | 15 | error colour at or below, 0–100 |
| hideWhenEmpty | ToggleSetting | true | collapse the pill with no devices |

Settings instantiate `BatteryModel` (same-directory QML import) so the pinned
dropdown filters identically and grows when a device connects. A pinned device
that isn't currently connected still displays its stored string; the pill falls
back to `lowest`.

`pollInterval` from PRD §8 is **dropped**: it only applied to the BlueZ fallback,
which is out of scope. It comes back with that fallback.

## Files and manifest

Repository root *is* the plugin; `make install` symlinks it to
`~/.config/DankMaterialShell/plugins/BluetoothBattery` (DMS reads `plugin.json`
per directory and only the manifest `id` has to be unique, as `CryptoTicker`
demonstrates).

```
.
├── plugin.json
├── BluetoothBatteryWidget.qml
├── BluetoothBatterySettings.qml
├── BatteryModel.qml
├── DESIGN.md          this document
├── README.md          what it does, install, settings, troubleshooting
├── AGENTS.md          commands, API facts, conventions for agents
├── Makefile           install/uninstall/reload/check/logs
├── mise.toml          same tasks for mise users
├── .editorconfig
└── .gitignore
```

`plugin.json` (schema `/usr/share/quickshell/dms/PLUGINS/plugin-schema.json`;
`capabilities` is required, which the PRD's draft omitted):

```json
{
  "id": "bluetoothBattery",
  "name": "Bluetooth Battery",
  "description": "Battery percentage of connected Bluetooth devices in DankBar",
  "version": "0.1.0",
  "author": "ntxinh",
  "icon": "battery_android_full",
  "type": "widget",
  "capabilities": ["dankbar-widget"],
  "component": "./BluetoothBatteryWidget.qml",
  "settings": "./BluetoothBatterySettings.qml",
  "requires_dms": ">=1.4.4",
  "permissions": ["settings_read", "settings_write"]
}
```

## Tooling

- `make install` — symlink repo into the plugins dir (idempotent, refuses to
  clobber a real directory); `make uninstall` removes a symlink only.
- `make reload` — `dms ipc call plugins reload bluetoothBattery`.
- `make check` — parse `plugin.json` (python3), warn if `qmllint` is absent,
  run it on the three QML files when present.
- `make logs` — `journalctl --user -u dms -f` (the unit is running).
- `make status` — `dms ipc call plugins list | grep -i bluetoothBattery`.
- `mise.toml` defines the same tasks (`mise run reload`), delegating to `make`
  so behaviour is identical; no tools to pin.
- `.editorconfig`: UTF-8, LF, final newline, 4-space indent for QML/JS,
  2-space for JSON/TOML, tabs for Makefile, no trailing-whitespace trimming in
  Markdown.
- `.gitignore`: no build output exists; ignore editor/OS droppings, `*.qmlc`,
  and `.qmllint/` caches.

## Verification

1. `make install && make status` — plugin listed, not in an "incompatible" state.
2. `make reload`, then `make logs` — no QML errors for `bluetoothBattery`.
3. Real device: pill shows `85%` for the MX Anywhere 3; open the popout, one row
   with name and bar.
4. Set `warnThreshold` to 90 → pill turns warning; `criticalThreshold` to 90 →
   error; revert.
5. `pinnedDevice` set to the mouse, then switch to a second device in `all` mode.
6. Empty case: no peripherals with batteries → pill collapses when
   `hideWhenEmpty`, stays with the empty message when not.
7. Restart the shell (`systemctl --user restart dms`) → state comes back.
8. Vertical bar (if configured) → icon over percentage, readable.

## Risks

- `percentage: 0` before the first report — filtered out (anti-goal 1).
- Two devices with the same `model` — pin resolves to the first; `nativePath`
  tiebreak only when the model is ambiguous.
- `setVisibilityOverride` is the one API that collapses a pill, but it also
  serves `dms ipc` show/hide; a manual IPC hide will be re-applied on the next
  data change. Documented as a soft dependency.
- DMS internals move between versions; `requires_dms` is pinned at the tested
  `1.4.4` and `AGENTS.md` records the paths used.
- Speakers/`OtherAudio` are included though PRD §5 lists only
  headset/headphones; a speaker with a battery is a peripheral worth showing.

## Left to the builder

- Exact spacing/icon sizes that look right next to stock DankBar widgets.
- Whether Material Symbols carries every chosen icon name on this font build.
- Popout row polish (bar width, `Layout` details) within the stated structure.
- BlueZ `Battery1` fallback and notifications — separate rounds.
