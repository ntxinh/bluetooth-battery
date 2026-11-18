# Bluetooth Battery

A [DankMaterialShell](https://danklinux.com) widget for DankBar that shows the
battery percentage of connected Bluetooth peripherals — mouse, keyboard,
headset, gamepad — read straight from UPower. Click the pill for a popout that
lists every device.

No polling, no subprocesses: the pill updates from UPower's property changes.

## Requirements

- DankMaterialShell `>= 1.4.4` on Wayland
- UPower running (it is on any DMS desktop)

## Install

```bash
git clone <this repo> ~/GitRepos/bluetooth-battery
cd bluetooth-battery
make install
```

`make install` symlinks the repo into
`~/.config/DankMaterialShell/plugins/BluetoothBattery`, so `git pull` updates the
installed plugin and `make uninstall` removes it without touching the repo.

Then add **Bluetooth Battery** to your bar: DMS Settings → Bar → your bar →
drag the widget in (or add `{"id": "bluetoothBattery", "enabled": true}` to a
bar's widget list in `~/.config/DankMaterialShell/settings.json`).

## What it shows

- **Lowest battery** (default): the connected peripheral closest to dying.
- **All devices**: one icon + percentage per device.
- **Pinned device**: the device you pick, falling back to the lowest one while
  it is not connected.
- **Colours**: charging → primary, at or below `criticalThreshold` → error, at
  or below `warnThreshold` → warning, otherwise normal text.
- **Filtering**: only UPower devices that are present, ready, not the laptop
  battery and not line power, of a peripheral type (mouse, keyboard,
  headset/headphones, speakers, gaming input, phone, tablet, touchpad, pen,
  PDA, wearable, remote, toy). A device reporting `0%` before its first charge
  report is treated as "no data" and hidden, not shown as empty.

## Settings

| Key | Default | Description |
|---|---|---|
| Display mode | `lowest` | `lowest`, `all` or `pinned` |
| Pinned device | none | Device shown in pinned mode; falls back to the lowest while offline |
| Show device name | off | Append the name to the pill (lowest/pinned) |
| Warning threshold | 30% | Warning colour at or below |
| Critical threshold | 15% | Error colour at or below |
| Hide when empty | on | Collapse the pill when nothing reports a battery |

## Troubleshooting

```bash
make status   # is the plugin loaded?
make reload   # hot reload after edits
make logs     # follow the shell journal
make check    # validate the manifest, lint QML if qmllint is installed
```

If no device appears, confirm UPower sees it first:

```bash
upower -e | grep -i battery
upower -i /org/freedesktop/UPower/devices/battery_hidpp_battery_1
```

Some devices only report battery through the vendor stack (e.g. Logitech
Unifying receivers surface via HID++/UPower, not BlueZ) — if UPower has no
device, this widget has nothing to show.

## Status

Covers the PRD's M1–M3 plus live connect/disconnect. Not yet implemented: the
BlueZ `org.bluez.Battery1` fallback for devices UPower misses, low-battery
notifications, a Control Center tile (needs DMS ≥ 1.5), and registry
publishing. See `DESIGN.md` for the design and
`docs/superpowers/plans/2026-11-18-bluetooth-battery.md` for the plan.
