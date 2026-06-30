import QtQuick
import QtQuick.Controls
import Quickshell.Io

Item {
    id: batterySliderRoot
    width: parent.width
    height: 48

    property bool batteryAvailable: false
    property int batteryCapacity: 0
    property bool batteryCharging: false
    property string percentageText: batteryAvailable ? batteryCapacity + "%" : "No Battery"

    FontConfig { id: fc }

    Timer {
        id: statPoller
        interval: 3000
        running: batterySliderRoot.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            batteryFetcher.running = true
        }
    }

    // Consolidated process to read stats safely without console spam
    Process {
        id: batteryFetcher
        command: ["sh", "-c", "if [ -d /sys/class/power_supply/BAT0 ]; then echo \"OK\"; cat /sys/class/power_supply/BAT0/capacity; cat /sys/class/power_supply/BAT0/status; else echo \"MISSING\"; fi 2>/dev/null"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                let lines = this.text.trim().split("\n")
                if (lines.length >= 3 && lines[0] === "OK") {
                    batterySliderRoot.batteryCapacity = parseInt(lines[1])
                    batterySliderRoot.batteryCharging = (lines[2] === "Charging")
                    batterySliderRoot.batteryAvailable = true
                } else {
                    batterySliderRoot.batteryAvailable = false
                }
                batteryFetcher.running = false
            }
        }
    }

    Rectangle {
        id: bgTrack
        anchors.fill: parent
        color: Qt.rgba(1, 1, 1, 0.05)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.03)
        radius: height / 2
        clip: true
        opacity: batterySliderRoot.batteryAvailable ? 1.0 : 0.5

        Text {
            anchors.centerIn: parent
            text: batterySliderRoot.percentageText
            color: Qt.rgba(1, 1, 1, 0.35)
            font.family: fc.mainFont
            font.pixelSize: 13
            font.weight: Font.Bold
            Component.onCompleted: fc.applyOutline(this, Qt.rgba(0, 0, 0, 0.35))
        }

        Rectangle {
            id: fillBar
            height: parent.height
            width: !batterySliderRoot.batteryAvailable ? parent.height : parent.height + ((parent.width - parent.height) * (batterySliderRoot.batteryCapacity / 100))
            color: "#ffffff"
            radius: height / 2
            anchors.left: parent.left
            anchors.leftMargin: 0
            clip: true

            Text {
                x: (batterySliderRoot.width - width) / 2 - fillBar.anchors.leftMargin
                y: (batterySliderRoot.height - height) / 2
                text: batterySliderRoot.percentageText
                color: Qt.rgba(0, 0, 0, 0.85)
                font.family: fc.mainFont
                font.pixelSize: 13
                font.weight: Font.Bold
                Component.onCompleted: fc.applySmoothing(this)
            }
        }

        Text {
            id: bgIcon
            text: {
                if (!batterySliderRoot.batteryAvailable) return "battery_unknown"
                if (batterySliderRoot.batteryCharging) return "battery_charging_full"
                if (batterySliderRoot.batteryCapacity > 85) return "battery_full"
                if (batterySliderRoot.batteryCapacity > 50) return "battery_60"
                if (batterySliderRoot.batteryCapacity > 25) return "battery_30"
                return "battery_alert"
            }
            font.family: fc.iconFont
            font.pixelSize: 18
            color: Qt.rgba(1, 1, 1, 0.4)
            anchors.left: parent.left
            anchors.leftMargin: 15
            anchors.verticalCenter: parent.verticalCenter
            anchors.horizontalCenter: parent.horizontalCenter
            Component.onCompleted: fc.applyOutline(this, Qt.rgba(0, 0, 0, 0.35))
        }

        Item {
            height: parent.height
            width: fillBar.width
            clip: true

            Text {
                text: {
                    if (!batterySliderRoot.batteryAvailable) return "battery_unknown"
                    if (batterySliderRoot.batteryCharging) return "battery_charging_full"
                    if (batterySliderRoot.batteryCapacity > 85) return "battery_full"
                    if (batterySliderRoot.batteryCapacity > 50) return "battery_60"
                    if (batterySliderRoot.batteryCapacity > 25) return "battery_30"
                    return "battery_alert"
                }
                font.family: fc.iconFont
                font.pixelSize: 18
                color: Qt.rgba(0, 0, 0, 0.75)
                x: 16
                anchors.verticalCenter: parent.verticalCenter
                anchors.horizontalCenter: parent.horizontalCenter
                Component.onCompleted: fc.applySmoothing(this)
            }
        }
    }
}
