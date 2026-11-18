# Spec: `bluetoothBattery` — DankBar plugin for Bluetooth device battery

## 1. Goal
Show the battery percentage of connected Bluetooth devices (mouse, keyboard,
headphones, etc.) in DankBar, with a popout listing all devices.

## 2. Environment
- Fedora 44, Wayland, niri, DankMaterialShell, fish
- Plugin location: `~/.config/DankMaterialShell/plugins/BluetoothBattery/`

## 3. Non-goals
- Pairing/connecting devices (DMS already does this)
- Notifications (possible later via a daemon/composite plugin)
- Supporting non-Linux backends

## 4. Plugin type
- `type: "widget"` (DankBar pill + popout)
- Provides `horizontalBarPill` and `verticalBarPill`
- Future: Control Center tile, low-battery daemon (composite plugin, DMS >= 1.5)

## 5. Data source
Primary (and only for v1): **UPower**, through Quickshell's UPower service.

- Select devices by **type**, never by object path. Paths such as
  `battery_hidpp_battery_1` are driver-specific and the index can change.
- Include types: mouse, keyboard, headset/headphones, gaming input, phone,
  tablet, other peripherals.
- Exclude: line power, the laptop's own battery (`power supply: yes`), UPS, and
  devices with `present: no`.
- Use `model` as the display name (e.g. "MX Anywhere 3"), `percentage` for the
  value, and `state` for charging/discharging.
- Reactive: bind to the service's device list and property changes, no polling.

Verified on the target machine:
- `upower -i .../battery_hidpp_battery_1` -> type mouse, MX Anywhere 3, 85%
- `bluetoothctl info` -> Battery Percentage 85 (same value)

Deferred (post-v1): BlueZ `org.bluez.Battery1` fallback for devices that
BlueZ sees but UPower does not (some headphones).

## 6. Data model
```qml
// per device
{ id: string, name: string, kind: "mouse"|"keyboard"|"headset"|"other",
  percentage: int (0-100), charging: bool, connected: bool }
```

## 7. UI

### 7.1 Bar pill
- Icon by device kind (Material Symbols: `mouse`, `keyboard`, `headphones`,
  `bluetooth`) + `NN%`
- Display modes (setting): `lowest` (default) | `all` | `pinned device`
- Color: normal -> `Theme.surfaceText`; <= warn threshold -> `Theme.warning`;
  <= critical threshold -> `Theme.error`; charging -> `Theme.primary`
- Hidden when no device reports battery (setting: `hideWhenEmpty`, default true)
- Vertical bar: icon over percentage, smaller font

### 7.2 Popout (on click)
- Header: "Bluetooth Devices"
- Row per device: icon, name, progress bar, percentage, charging indicator
- Empty state: "No Bluetooth devices reporting battery"

## 8. Settings (`BluetoothBatterySettings.qml`)
| Key | Type | Default | Description |
|---|---|---|---|
| displayMode | enum | lowest | lowest / all / pinned |
| pinnedDevice | string | "" | Device id/MAC when pinned |
| showName | bool | false | Show device name in pill |
| warnThreshold | int | 30 | Warning color at or below |
| criticalThreshold | int | 15 | Critical color at or below |
| hideWhenEmpty | bool | true | Hide pill without data |
| pollInterval | int (s) | 60 | Only used by fallback source |

## 9. File layout
```
BluetoothBattery/
  plugin.json
  BluetoothBatteryWidget.qml     # PluginComponent, pills + popout
  BluetoothBatterySettings.qml
  BatteryModel.qml               # data source abstraction (UPower/BlueZ)
  README.md
```

## 10. Manifest (`plugin.json`)
```json
{
  "id": "bluetoothBattery",
  "name": "Bluetooth Battery",
  "description": "Battery percentage of connected Bluetooth devices in DankBar",
  "version": "0.1.0",
  "author": "<you>",
  "icon": "battery_android_full",
  "type": "widget",
  "component": "./BluetoothBatteryWidget.qml",
  "settings": "./BluetoothBatterySettings.qml",
  "permissions": ["settings_read", "settings_write"]
}
```
(Confirm field names against the manifest schema for your DMS version.)

## 11. Milestones
1. **M1 (MVP):** pill shows lowest-battery connected BT device from UPower.
2. **M2:** popout with all devices; vertical bar support.
3. **M3:** settings UI, thresholds, colors, pinned device.
4. **M4:** BlueZ D-Bus fallback; handle connect/disconnect live.
5. **M5:** low-battery notification (daemon), Control Center tile, publish to
   the DMS plugin registry.

## 12. Testing
- `dms ipc call plugins reload bluetoothBattery` for hot reload
- Run `dms kill && dms run` in a terminal to read QML errors
- Cases: device connects/disconnects, battery drops below thresholds, no BT
  adapter, adapter off, multiple devices, charging state, vertical bar

## 13. Risks
- Not all devices expose battery to UPower/BlueZ (vendor dongles, e.g. Logitech
  Unifying, usually appear via HID++/UPower rather than BlueZ).
- Plugin API may change between DMS versions; pin `requires_dms` if supported.
- UPower percentage may be 0/unknown until first report; treat as "no data".

## 14. References
- Plugin dev guide: https://danklinux.com/docs/dankmaterialshell/plugin-development
- Plugins overview: https://danklinux.com/docs/dankmaterialshell/plugins-overview
- Registry: https://plugins.danklinux.com/