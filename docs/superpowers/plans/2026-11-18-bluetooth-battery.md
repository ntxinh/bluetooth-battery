# Bluetooth Battery Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A DankBar widget that shows connected peripherals' battery from UPower, with a per-device popout and settings.

**Architecture:** One `BatteryModel.qml` normalises `UPower.devices` into a filtered, sorted array; the widget renders pills from it, the popout lists it, and the settings file instantiates the same model for the pinned-device dropdown. No polling — QML bindings on UPower properties drive every update.

**Tech Stack:** QML (Qt 6, Quickshell), DankMaterialShell 1.4.4 plugin API, UPower via `Quickshell.Services.UPower`. Repo tooling: `make`, `mise`, python3 (manifest check).

**Spec:** `DESIGN.md`

## Global Constraints

- Plugin id `bluetoothBattery`; manifest `author: "ntxinh"`, `version: "0.1.0"`, `requires_dms: ">=1.4.4"`, `capabilities: ["dankbar-widget"]`, `permissions: ["settings_read", "settings_write"]`.
- `UPowerDevice.percentage` is **0.0–1.0**; every displayed value is `Math.round(percentage * 100)`.
- Zero polling: no `Timer`, no `Process`, no `upower`/`bluetoothctl` calls anywhere.
- Never show a device whose rounded percentage is 0 (UPower's "no report yet").
- QML: 4-space indent, imports `QtQuick`, `qs.Common`, `qs.Widgets`, `qs.Modules.Plugins`, `Quickshell.Services.UPower`.
- Settings keys exactly: `displayMode`, `pinnedDevice`, `showName`, `warnThreshold`, `criticalThreshold`, `hideWhenEmpty`. No `pollInterval` this round.
- Icons: `mouse`, `keyboard`, `headphones`, `bluetooth`, `bolt`.
- Do not commit unless the human asks.

## Review Focus

- Nothing connected / no peripherals: pill collapses, popout shows the empty message, no QML warnings in the journal.
- A peripheral reporting 0% or unknown charge: excluded entirely, never rendered as "0%".
- Laptop battery (`BAT0`) and AC line power: never in the list, even though UPower exposes them.
- Pinned device asleep or gone: the pill falls back to the lowest device instead of blanking.
- A device disconnecting while the popout is open: rows update in place, no crash, no stale name left behind.

---

### Task 1: `BatteryModel.qml` — filtered, sorted device data

**Files:**
- Create: `BatteryModel.qml`
- Test: throwaway Quickshell probe in `/tmp/btb-probe/` (symlinked model, deleted after)

**Interfaces:**
- Consumes: `Quickshell.Services.UPower` (`UPower.devices`, `UPowerDevice`, `UPowerDeviceType`, `UPowerDeviceState`).
- Produces: `BatteryModel { property string displayMode /* "lowest" | "all" | "pinned" */, property string pinnedDevice, readonly property var devices, readonly property var primaryDevice, function kindOf(type) }`.
  Each element of `devices`: `{ id: string, name: string, kind: "mouse"|"keyboard"|"headset"|"other", percentage: int 0–100, charging: bool, connected: bool }`.
  `primaryDevice` is `null` when `devices` is empty.

- [ ] **Step 1: Write the probe (failing test)**

`/tmp/btb-probe/shell.qml`:

```qml
import QtQuick
import Quickshell

ShellRoot {
    BatteryModel {
        id: battery

        Component.onCompleted: {
            console.log("PROBE " + JSON.stringify(battery.devices));
            console.log("PRIMARY " + JSON.stringify(battery.primaryDevice));
            Quickshell.quit();
        }
    }
}
```

Run: `ln -sf "$PWD/BatteryModel.qml" /tmp/btb-probe/BatteryModel.qml && WAYLAND_DISPLAY=wayland-1 quickshell --path /tmp/btb-probe 2>&1 | grep -E "PROBE|PRIMARY|error"`
Expected: FAIL — `BatteryModel.qml` does not exist yet.

- [ ] **Step 2: Write `BatteryModel.qml`**

`QtObject`, no `qs.*` imports (the probe runs outside the shell's import path). Inclusion predicate, in order: `dev.isPresent && dev.ready`; `!dev.isLaptopBattery && !dev.powerSupply`; `dev.type` in the allow-list (`Mouse`, `Keyboard`, `Headset`, `Headphones`, `Speakers`, `OtherAudio`, `BluetoothGeneric`, `GamingInput`, `Phone`, `Tablet`, `Touchpad`, `Pen`, `Pda`, `Wearable`, `RemoteControl`, `Toy`); `Math.round(dev.percentage * 100) > 0`. `id` is `dev.nativePath`, `name` is `dev.model || <type name>`, `charging` is `state === UPowerDeviceState.Charging`, `connected` is `isPresent && ready`. Sort ascending by percentage. `kindOf`: `Mouse`→`mouse`, `Keyboard`→`keyboard`, `Headset`/`Headphones`/`Speakers`/`OtherAudio`→`headset`, otherwise `other`. `primaryDevice`: for `pinned`, match `pinnedDevice` against `name` case-insensitively then `id`, else fall back to `devices[0]`; otherwise `devices[0] || null`.

- [ ] **Step 3: Run the probe again**

Run: `WAYLAND_DISPLAY=wayland-1 quickshell --path /tmp/btb-probe 2>&1 | grep -E "PROBE|PRIMARY|error"`
Expected: PASS — `PROBE [{"id":"hidpp_battery_1","name":"MX Anywhere 3","kind":"mouse","percentage":85,"charging":false,"connected":true}]` and `PRIMARY` the same object. `BAT0` and `line_power_*` absent.
If Quickshell refuses to start without a shell root owning a window, run the probe through `dms`-installed modules instead: copy `BatteryModel.qml` into a scratch plugin dir and read `console.log` from `journalctl --user -u dms` after `make reload`.

- [ ] **Step 4: Delete the probe**

Run: `rm -rf /tmp/btb-probe`

---

### Task 2: Manifest, Makefile, and the bar pills

**Files:**
- Create: `plugin.json`, `Makefile`, `BluetoothBatteryWidget.qml`

**Interfaces:**
- Consumes: `BatteryModel` (Task 1).
- Produces: `Makefile` targets `install`, `uninstall`, `reload`, `status`, `check`, `logs`, `help`; widget properties `displayMode`/`pinnedDevice`/`showName`/`warnThreshold`/`criticalThreshold`/`hideWhenEmpty` read from `pluginData`, plus `function colorFor(percentage, charging)` and `function applyVisibility()` used again in Tasks 3–4.

- [ ] **Step 1: Write `plugin.json`**

Exactly the manifest in `DESIGN.md` § "Files and manifest".

- [ ] **Step 2: Write the `Makefile`**

`PLUGIN_DIR := $(HOME)/.config/DankMaterialShell/plugins/BluetoothBattery`. `install` creates the plugins dir (`mkdir -p`), refuses if `$(PLUGIN_DIR)` exists and is not a symlink, else `ln -sfn $(CURDIR) $(PLUGIN_DIR)`. `uninstall` removes it only when it is a symlink. `reload` runs `dms ipc call plugins reload bluetoothBattery`. `status` runs `dms ipc call plugins list | grep -i bluetoothBattery`. `check` validates `plugin.json` with `python3 -c 'import json,sys;json.load(open("plugin.json"))'` and runs `qmllint` on the three QML files only when `command -v qmllint` succeeds (print a skip note otherwise). `logs` runs `journalctl --user -u dms -f`. `help` is the default goal and lists all targets. Every target `.PHONY`.

- [ ] **Step 3: Install and verify it loads**

Run: `make install && make status`
Expected: `bluetoothBattery [loaded]` (or listed before its component exists — carry on to Step 4 and re-check).

- [ ] **Step 4: Write the pills in `BluetoothBatteryWidget.qml`**

`PluginComponent` root with `BatteryModel { id: battery; displayMode: root.displayMode; pinnedDevice: root.pinnedDevice }`, settings properties read from `pluginData` with the `DESIGN.md` defaults (`displayMode || "lowest"`, thresholds via `SliderSetting` range 0–100, `hideWhenEmpty !== undefined ? ... : true`). `colorFor`: charging → `Theme.primary`, `<= criticalThreshold` → `Theme.error`, `<= warnThreshold` → `Theme.warning`, else `Theme.surfaceText`. `applyVisibility()` calls `setVisibilityOverride(!(hideWhenEmpty && battery.devices.length === 0))`, wired from `Component.onCompleted`, `Connections { target: battery; function onDevicesChanged() { root.applyVisibility() } }`, and `onPluginDataChanged`.
Horizontal pill: `Row` of icon (`kind === "headset" ? "headphones" : kind`, `other`→`bluetooth`) + `NN%` for `lowest`/`pinned`, or one icon+`NN%` group per device for `all`; optional name when `showName` and mode is not `all`; empty + `hideWhenEmpty` off renders `bluetooth` + `--` in `Theme.surfaceVariantText`.
Vertical pill: `Column`, icon over `NN%` at `Theme.fontSizeSmall`, same colours, `all` stacks groups.

- [ ] **Step 5: Reload and verify no QML errors**

Run: `make reload && sleep 2 && journalctl --user -u dms --since "-2min" --no-pager | grep -i -E "bluetoothbattery|error|warning" | tail -20`
Expected: no `TypeError`, no `Unable to assign`, no "is not a type"; plugin pill appears in the bar showing `85%`.

---

### Task 3: Popout

**Files:**
- Modify: `BluetoothBatteryWidget.qml`

**Interfaces:**
- Consumes: `battery.devices`, `root.colorFor`.
- Produces: `popoutContent` Component, `popoutWidth: 380`, `popoutHeight: 0`.

- [ ] **Step 1: Add the popout**

`popoutContent: Component { PopoutComponent { headerText: "Bluetooth Devices"; showCloseButton: true; Column { width: parent.width; spacing: ...; Repeater { model: battery.devices; ... } } } }`. Row per device, `RowLayout` at `parent.width`: `DankIcon` kind icon; `StyledText` name (`Layout.fillWidth`, `elide: Text.ElideRight`); 6 px radius-3 track in `Theme.outline` at 0.35 opacity with a proportional fill in `root.colorFor(dev.percentage, dev.charging)`; `NN%`; `bolt` icon when `dev.charging`. Empty state: single `StyledText` "No Bluetooth devices reporting battery" in `Theme.surfaceVariantText`.

- [ ] **Step 2: Reload and verify**

Run: `make reload && sleep 2 && journalctl --user -u dms --since "-2min" --no-pager | grep -i -E "bluetoothbattery|error" | tail -20`
Expected: no QML errors. Clicking the pill opens a popout headed "Bluetooth Devices" with one row for the MX Anywhere 3 at 85%, and the popout height fits the content (no scrolling, no clipped last row).

- [ ] **Step 3: Check the empty and live-update cases**

With no peripheral reporting battery (or `hideWhenEmpty` toggled off in `~/.config/DankMaterialShell/plugin-settings.json`), confirm the popout shows the empty message and the pill shows `bluetooth --`. Disconnect and reconnect the mouse; the row disappears and returns without a reload.

---

### Task 4: Settings UI

**Files:**
- Create: `BluetoothBatterySettings.qml`

**Interfaces:**
- Consumes: `BatteryModel { id: battery }` (Task 1), inherited `saveValue`/`loadValue` from `PluginSettings`.
- Produces: the six settings keys listed under Global Constraints.

- [ ] **Step 1: Write the settings component**

`PluginSettings { pluginId: "bluetoothBattery" }` containing `BatteryModel { id: battery }`, then: `SelectionSetting` `displayMode` options `[{label:"Lowest battery",value:"lowest"},{label:"All devices",value:"all"},{label:"Pinned device",value:"pinned"}]`, default `"lowest"`; `SelectionSetting` `pinnedDevice` with `options: [{label:"None",value:""}].concat(battery.devices.map(d => ({label: d.name, value: d.name})))`, default `""`; `ToggleSetting` `showName` default false; `SliderSetting` `warnThreshold` default 30 (0–100); `SliderSetting` `criticalThreshold` default 15 (0–100); `ToggleSetting` `hideWhenEmpty` default true. Descriptions state that warning applies at or below `warnThreshold` and error at or below `criticalThreshold`.

- [ ] **Step 2: Reload and verify the settings render**

Run: `make reload && sleep 2 && journalctl --user -u dms --since "-2min" --no-pager | grep -i -E "bluetoothbattery|error" | tail -20`
Expected: no errors; Settings → Plugins → Bluetooth Battery shows all six controls and the pinned dropdown lists "None" + "MX Anywhere 3".

- [ ] **Step 3: Exercise thresholds and pinning**

Set `warnThreshold` 90 → pill turns warning; set `criticalThreshold` 90 → error; revert both. Set `displayMode` pinned with the mouse selected → pill unchanged; set `pinnedDevice` to a name that is not connected (edit the settings JSON) → pill falls back to the lowest device rather than blanking. Restore `displayMode` lowest.

---

### Task 5: Docs and repo tooling

**Files:**
- Create: `README.md`, `AGENTS.md`, `mise.toml`, `.editorconfig`, `.gitignore`

**Interfaces:**
- Consumes: the finished plugin and `Makefile` targets from Task 2.
- Produces: nothing later tasks use.

- [ ] **Step 1: Write `README.md`**

What it does, requirements (DMS ≥ 1.4.4, UPower, Linux/Wayland), install (`make install`, enable in bar settings), settings table from `DESIGN.md` (no `pollInterval`), how devices are chosen (type allow-list, no 0%), troubleshooting (`make status`, `make reload`, `make logs`), and a line that BlueZ fallback/notifications are planned, not present.

- [ ] **Step 2: Write `AGENTS.md`**

Repo purpose and layout; commands (`make install/reload/check/logs`, `mise run …`); DMS API facts verified on 1.4.4 (percentage 0–1, `nativePath`, `isPresent`/`isLaptopBattery`, `setVisibilityOverride`, popout auto-height, `pluginData` reload, `qs.*` import paths, plugin sources under `/usr/share/quickshell/dms/`, UPower qmltypes under `/usr/lib64/qt6/qml/Quickshell/Services/UPower/`); conventions (4-space QML, no polling, one model for all views); no test suite — verification is `make check` + `make reload` + journal, and `qmllint` is absent on this machine.

- [ ] **Step 3: Write `mise.toml`**

`[tasks]` `install`, `uninstall`, `reload`, `status`, `check`, `logs` each `run = "make <target>"`, with descriptions; no `[tools]` entries.

- [ ] **Step 4: Write `.editorconfig` and `.gitignore`**

`.editorconfig`: `root = true`, `charset = utf-8`, `end_of_line = lf`, `insert_final_newline = true`; `[*.{qml,js}]` 4 spaces; `[*.{json,toml}]` 2 spaces; `[*.md]` `trim_trailing_whitespace = false`; `[Makefile]` `indent_style = tab`.
`.gitignore`: `.DS_Store`, `*.qmlc`, `.qmllint/`, `*.swp`, `*~`.

- [ ] **Step 5: Final end-to-end check**

Run: `make check && make reload && sleep 2 && make status && journalctl --user -u dms --since "-2min" --no-pager | grep -i -E "bluetoothbattery|error" | tail -20`
Expected: manifest parses, lint skipped or clean, plugin `[loaded]`, and no errors in the journal. Then `systemctl --user restart dms` and confirm the pill and popout still work after a full shell restart.
