import QtQuick
import QtQuick.Controls
import Quickshell.Io

Item {
    id: batterySliderRoot
    width: parent.width
    height: 36 // Shorter overall height

    // Production logic state bindings
    property bool batteryAvailable: false
    property int batteryCapacity: 0
    property bool batteryCharging: false
    
    // Status text generation logic
    property string statusText: !batteryAvailable ? "" : (batteryCharging ? "Charging" : (batteryCapacity >= 95 ? "Charged" : "Discharging"))
    property string combinedText: batteryAvailable ? batteryCapacity + "% • " + statusText : "No Battery"

    FontConfig { id: fc }

    Timer {
        id: statPoller
        interval: 3000
        running: batterySliderRoot.visible // Production polling activated on visibility
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            batteryFetcher.running = true
        }
    }

    Process {
        id: batteryFetcher
        // Iterates through expected battery directories, grabs metrics from the first one found, then exits the loop
        command: ["sh", "-c", "for b in BAT0 BAT1; do if [ -d /sys/class/power_supply/$b ]; then echo \"OK\"; cat /sys/class/power_supply/$b/capacity; cat /sys/class/power_supply/$b/status; exit 0; fi; done; echo \"MISSING\""]
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

        // --- STATIC LEFT ICON (BACKGROUND) ---
        Text {
            id: bgIcon
            visible: !batterySliderRoot.batteryAvailable || fillBar.width < (x + width)
            text: {
                if (!batterySliderRoot.batteryAvailable) return "battery_android_0"
                if (batterySliderRoot.batteryCharging) return "battery_android_frame_bolt"
                if (batterySliderRoot.batteryCapacity >= 95) return "battery_android_frame_full"
                
                let step = Math.min(6, Math.max(1, Math.ceil(batterySliderRoot.batteryCapacity / 15.8)))
                return "battery_android_frame_" + step
            }
            font.family: fc.iconFont
            font.pixelSize: 24
            color: Qt.rgba(1, 1, 1, 0.4)
            
            width: 24
            height: 24
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            
            anchors.left: parent.left
            anchors.leftMargin: 15
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: 0
            Component.onCompleted: fc.applySmoothing(this)
        }

        // --- LEFT-ALIGNED STATUS TEXT (BACKGROUND) ---
        Text {
            id: bgLabel
            visible: !batterySliderRoot.batteryAvailable || fillBar.width < (x + width)
            anchors.left: bgIcon.right
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: batterySliderRoot.combinedText
            color: Qt.rgba(1, 1, 1, 0.35)
            font.family: fc.mainFont
            font.pixelSize: 13
            font.weight: Font.Bold
            Component.onCompleted: fc.applySmoothing(this)
        }

        // --- PROGRESS FILL BAR ---
        Rectangle {
            id: fillBar
            height: parent.height
            // Set width to 0 if hardware is missing, eliminating the fallback white circle completely
            width: !batterySliderRoot.batteryAvailable ? 0 : parent.height + ((parent.width - parent.height) * (batterySliderRoot.batteryCapacity / 100))
            color: "#ffffff"
            radius: height / 2
            anchors.left: parent.left
            anchors.leftMargin: 0
            clip: true
            visible: batterySliderRoot.batteryAvailable // Ensure layout bounds don't draw when missing

            // --- STATIC LEFT ICON (FOREGROUND OVERLAY) ---
            Text {
                id: fgIcon
                visible: batterySliderRoot.batteryAvailable && fillBar.width >= x
                text: bgIcon.text
                font.family: fc.iconFont
                font.pixelSize: 24
                color: Qt.rgba(0, 0, 0, 0.75)
                
                width: 24
                height: 24
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                
                x: 15
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: 0
                Component.onCompleted: fc.applySmoothing(this)
            }

            // --- LEFT-ALIGNED STATUS TEXT (FOREGROUND OVERLAY) ---
            Text {
                id: fgLabel
                visible: batterySliderRoot.batteryAvailable && fillBar.width >= x
                x: 49 // Absolute coordinate sync: 15 (Margin) + 24 (Width) + 10 (Gap)
                y: bgLabel.y
                text: batterySliderRoot.combinedText
                color: Qt.rgba(0, 0, 0, 0.85)
                font.family: fc.mainFont
                font.pixelSize: 13
                font.weight: Font.Bold
                Component.onCompleted: fc.applySmoothing(this)
            }
        }
    }
}
