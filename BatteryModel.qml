import QtQuick
import Quickshell.Services.UPower

// Normalised view of the UPower devices that are actually peripherals with a
// battery. Knows nothing about the bar, the theme or settings storage.
QtObject {
    id: root

    property string displayMode: "lowest"
    property string pinnedDevice: ""

    readonly property var allowedTypes: [
        UPowerDeviceType.Mouse,
        UPowerDeviceType.Keyboard,
        UPowerDeviceType.Headset,
        UPowerDeviceType.Headphones,
        UPowerDeviceType.Speakers,
        UPowerDeviceType.OtherAudio,
        UPowerDeviceType.BluetoothGeneric,
        UPowerDeviceType.GamingInput,
        UPowerDeviceType.Phone,
        UPowerDeviceType.Tablet,
        UPowerDeviceType.Touchpad,
        UPowerDeviceType.Pen,
        UPowerDeviceType.Pda,
        UPowerDeviceType.Wearable,
        UPowerDeviceType.RemoteControl,
        UPowerDeviceType.Toy
    ]

    // Ascending, so the device most likely to die comes first and the pill's
    // "lowest" mode is simply devices[0].
    readonly property var devices: {
        const out = [];
        const list = UPower.devices.values;
        for (var i = 0; i < list.length; i++) {
            const dev = list[i];
            if (!dev || !dev.ready || !dev.isPresent)
                continue;
            if (dev.isLaptopBattery || dev.powerSupply)
                continue;
            if (root.allowedTypes.indexOf(dev.type) === -1)
                continue;
            // UPower reports 0 before a device's first charge report; that is
            // "no data", not an empty battery.
            const percentage = Math.round(dev.percentage * 100);
            if (percentage <= 0)
                continue;
            out.push({
                "id": dev.nativePath,
                "name": dev.model || UPowerDeviceType.toString(dev.type),
                "kind": root.kindOf(dev.type),
                "percentage": percentage,
                "charging": dev.state === UPowerDeviceState.Charging,
                "connected": true
            });
        }
        out.sort((a, b) => a.percentage - b.percentage);
        return out;
    }

    readonly property var primaryDevice: {
        if (devices.length === 0)
            return null;
        if (displayMode === "pinned" && pinnedDevice) {
            const needle = pinnedDevice.toLowerCase();
            // Model first: UPower's native paths renumber, the model is what
            // the user picked in the dropdown.
            const match = devices.find(d => d.name.toLowerCase() === needle) || devices.find(d => d.id.toLowerCase() === needle);
            if (match)
                return match;
        }
        // Pinned device asleep or gone: fall back rather than blanking the pill.
        return devices[0];
    }

    function kindOf(type) {
        switch (type) {
        case UPowerDeviceType.Mouse:
            return "mouse";
        case UPowerDeviceType.Keyboard:
            return "keyboard";
        case UPowerDeviceType.Headset:
        case UPowerDeviceType.Headphones:
        case UPowerDeviceType.Speakers:
        case UPowerDeviceType.OtherAudio:
            return "headset";
        default:
            return "other";
        }
    }
}
