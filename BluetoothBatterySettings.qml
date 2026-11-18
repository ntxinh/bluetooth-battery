import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    pluginId: "bluetoothBattery"

    // Same model the widget uses, so the pinned dropdown sees the same
    // filtered devices and grows when one connects.
    BatteryModel {
        id: battery
    }

    SelectionSetting {
        settingKey: "displayMode"
        label: "Display mode"
        description: "Show the lowest battery, every device, or one pinned device"
        options: [
            {
                "label": "Lowest battery",
                "value": "lowest"
            },
            {
                "label": "All devices",
                "value": "all"
            },
            {
                "label": "Pinned device",
                "value": "pinned"
            }
        ]
        defaultValue: "lowest"
    }

    SelectionSetting {
        settingKey: "pinnedDevice"
        label: "Pinned device"
        description: "Shown in pinned mode. Falls back to the lowest battery while this device is not connected."
        options: [{
                "label": "None",
                "value": ""
            }].concat(battery.devices.map(d => ({
                    "label": d.name,
                    "value": d.name
                })))
        defaultValue: ""
    }

    ToggleSetting {
        settingKey: "showName"
        label: "Show device name"
        description: "Append the device name to the pill (lowest and pinned modes)"
        defaultValue: false
    }

    SliderSetting {
        settingKey: "warnThreshold"
        label: "Warning threshold"
        description: "Pill turns warning-coloured at or below this percentage"
        defaultValue: 30
        minimum: 0
        maximum: 100
        unit: "%"
    }

    SliderSetting {
        settingKey: "criticalThreshold"
        label: "Critical threshold"
        description: "Pill turns error-coloured at or below this percentage"
        defaultValue: 15
        minimum: 0
        maximum: 100
        unit: "%"
    }

    ToggleSetting {
        settingKey: "hideWhenEmpty"
        label: "Hide when empty"
        description: "Collapse the pill when no device reports a battery"
        defaultValue: true
    }
}
