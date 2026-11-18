import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    // Settings (pluginData reloads on change; see PluginComponent)
    property string displayMode: pluginData.displayMode || "lowest"
    property string pinnedDevice: pluginData.pinnedDevice || ""
    property bool showName: pluginData.showName === true
    property int warnThreshold: pluginData.warnThreshold !== undefined ? pluginData.warnThreshold : 30
    property int criticalThreshold: pluginData.criticalThreshold !== undefined ? pluginData.criticalThreshold : 15
    property bool hideWhenEmpty: pluginData.hideWhenEmpty !== undefined ? pluginData.hideWhenEmpty : true

    BatteryModel {
        id: battery
        displayMode: root.displayMode
        pinnedDevice: root.pinnedDevice
    }

    function iconFor(kind) {
        switch (kind) {
        case "mouse":
            return "mouse";
        case "keyboard":
            return "keyboard";
        case "headset":
            return "headphones";
        default:
            return "bluetooth";
        }
    }

    function colorFor(percentage, charging) {
        if (charging)
            return Theme.primary;
        if (percentage <= root.criticalThreshold)
            return Theme.error;
        if (percentage <= root.warnThreshold)
            return Theme.warning;
        return Theme.surfaceText;
    }

    // PluginComponent has no "render nothing" state, so an empty pill is
    // collapsed through the IPC visibility override. Settings changes arrive
    // as pluginData changes, UPower arrivals as devices changes, which is why
    // this needs no Component.onCompleted handler (it would shadow the base
    // component's).
    function applyVisibility() {
        setVisibilityOverride(!(root.hideWhenEmpty && battery.devices.length === 0));
    }

    popoutWidth: 380
    popoutHeight: 0

    onPluginDataChanged: applyVisibility()
    onHideWhenEmptyChanged: applyVisibility()

    Connections {
        target: battery

        function onDevicesChanged() {
            root.applyVisibility();
        }
    }

    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingXS

            Repeater {
                model: root.displayMode === "all" ? battery.devices : []

                Row {
                    spacing: Theme.spacingXS

                    DankIcon {
                        name: root.iconFor(modelData.kind)
                        size: root.iconSize - 6
                        color: root.colorFor(modelData.percentage, modelData.charging)
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    StyledText {
                        text: modelData.percentage + "%"
                        color: root.colorFor(modelData.percentage, modelData.charging)
                        font.pixelSize: Theme.fontSizeMedium
                        wrapMode: Text.NoWrap
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            Row {
                spacing: Theme.spacingXS
                visible: root.displayMode !== "all" && battery.primaryDevice !== null

                DankIcon {
                    name: root.iconFor(battery.primaryDevice ? battery.primaryDevice.kind : "other")
                    size: root.iconSize - 6
                    color: battery.primaryDevice ? root.colorFor(battery.primaryDevice.percentage, battery.primaryDevice.charging) : Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    text: battery.primaryDevice ? battery.primaryDevice.percentage + "%" : "--"
                    color: battery.primaryDevice ? root.colorFor(battery.primaryDevice.percentage, battery.primaryDevice.charging) : Theme.surfaceText
                    font.pixelSize: Theme.fontSizeMedium
                    wrapMode: Text.NoWrap
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    visible: root.showName && battery.primaryDevice !== null
                    text: battery.primaryDevice ? battery.primaryDevice.name : ""
                    color: Theme.surfaceVariantText
                    font.pixelSize: Theme.fontSizeSmall
                    wrapMode: Text.NoWrap
                    elide: Text.ElideRight
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Row {
                spacing: Theme.spacingXS
                visible: battery.devices.length === 0

                DankIcon {
                    name: "bluetooth"
                    size: root.iconSize - 6
                    color: Theme.surfaceVariantText
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    text: "--"
                    color: Theme.surfaceVariantText
                    font.pixelSize: Theme.fontSizeMedium
                    wrapMode: Text.NoWrap
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }

    verticalBarPill: Component {
        Column {
            spacing: Theme.spacingXS

            Repeater {
                model: root.displayMode === "all" ? battery.devices : []

                Column {
                    spacing: 0
                    anchors.horizontalCenter: parent.horizontalCenter

                    DankIcon {
                        name: root.iconFor(modelData.kind)
                        size: root.iconSize - 8
                        color: root.colorFor(modelData.percentage, modelData.charging)
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    StyledText {
                        text: modelData.percentage + "%"
                        color: root.colorFor(modelData.percentage, modelData.charging)
                        font.pixelSize: Theme.fontSizeSmall
                        wrapMode: Text.NoWrap
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }
            }

            Column {
                spacing: 0
                visible: root.displayMode !== "all" && battery.primaryDevice !== null
                anchors.horizontalCenter: parent.horizontalCenter

                DankIcon {
                    name: root.iconFor(battery.primaryDevice ? battery.primaryDevice.kind : "other")
                    size: root.iconSize - 8
                    color: battery.primaryDevice ? root.colorFor(battery.primaryDevice.percentage, battery.primaryDevice.charging) : Theme.surfaceText
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                StyledText {
                    text: battery.primaryDevice ? battery.primaryDevice.percentage + "%" : "--"
                    color: battery.primaryDevice ? root.colorFor(battery.primaryDevice.percentage, battery.primaryDevice.charging) : Theme.surfaceText
                    font.pixelSize: Theme.fontSizeSmall
                    wrapMode: Text.NoWrap
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }

            Column {
                spacing: 0
                visible: battery.devices.length === 0
                anchors.horizontalCenter: parent.horizontalCenter

                DankIcon {
                    name: "bluetooth"
                    size: root.iconSize - 8
                    color: Theme.surfaceVariantText
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                StyledText {
                    text: "--"
                    color: Theme.surfaceVariantText
                    font.pixelSize: Theme.fontSizeSmall
                    wrapMode: Text.NoWrap
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }
    }

    popoutContent: Component {
        PopoutComponent {
            headerText: "Bluetooth Devices"
            showCloseButton: true

            Column {
                width: parent.width
                spacing: Theme.spacingS

                Repeater {
                    model: battery.devices

                    RowLayout {
                        width: parent.width
                        spacing: Theme.spacingS

                        DankIcon {
                            name: root.iconFor(modelData.kind)
                            size: root.iconSize - 4
                            color: root.colorFor(modelData.percentage, modelData.charging)
                            Layout.alignment: Qt.AlignVCenter
                        }

                        StyledText {
                            text: modelData.name
                            color: Theme.surfaceText
                            font.pixelSize: Theme.fontSizeMedium
                            wrapMode: Text.NoWrap
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            Layout.alignment: Qt.AlignVCenter
                        }

                        Rectangle {
                            Layout.alignment: Qt.AlignVCenter
                            width: 90
                            height: 6
                            radius: 3
                            color: Theme.surfaceContainerHigh

                            Rectangle {
                                width: parent.width * modelData.percentage / 100
                                height: parent.height
                                radius: parent.radius
                                color: root.colorFor(modelData.percentage, modelData.charging)
                            }
                        }

                        StyledText {
                            text: modelData.percentage + "%"
                            color: root.colorFor(modelData.percentage, modelData.charging)
                            font.pixelSize: Theme.fontSizeMedium
                            wrapMode: Text.NoWrap
                            Layout.alignment: Qt.AlignVCenter
                        }

                        DankIcon {
                            visible: modelData.charging
                            name: "bolt"
                            size: root.iconSize - 8
                            color: Theme.primary
                            Layout.alignment: Qt.AlignVCenter
                        }
                    }
                }

                StyledText {
                    visible: battery.devices.length === 0
                    width: parent.width
                    text: "No Bluetooth devices reporting battery"
                    color: Theme.surfaceVariantText
                    font.pixelSize: Theme.fontSizeMedium
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }
}
