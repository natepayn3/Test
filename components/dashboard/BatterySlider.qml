import QtQuick
import QtQuick.Controls
import Quickshell.Io
import "../../configs"

Item {
    id: batterySliderRoot
    width: parent.width
    height: 36

    // Production logic state bindings
    property bool batteryAvailable: false
    property int batteryCapacity: 0
    property bool batteryCharging: false
    
    // Status text generation logic
    property string statusText: !batteryAvailable ? "" : (batteryCharging ? "Charging" : (batteryCapacity >= 99 ? "Charged" : "Discharging"))
    property string combinedText: batteryAvailable ? batteryCapacity + "% • " + statusText : "No Battery"

    FontConfig { id: fc }

    // Persistent background process with zero timers
    Process {
        id: batteryFetcher
        command: ["sh", "-c", "fetch() { for b in BAT0 BAT1; do if [ -d /sys/class/power_supply/$b ]; then cap=$(cat /sys/class/power_supply/$b/capacity); stat=$(cat /sys/class/power_supply/$b/status); echo \"$cap;$stat\"; break; fi; done; }; fetch; while true; do sleep 30; fetch; done"]
        running: batterySliderRoot.visible
        
        stdout: SplitParser {
            onRead: data => {
                let cleanData = data.trim();
                if (cleanData === "") return;

                let segments = cleanData.split(";");
                if (segments.length === 2) {
                    batterySliderRoot.batteryCapacity = parseInt(segments[0]);
                    batterySliderRoot.batteryCharging = (segments[1] === "Charging");
                    batterySliderRoot.batteryAvailable = true;
                } else {
                    batterySliderRoot.batteryAvailable = false;
                }
            }
        }
    }

    Rectangle {
        id: bgTrack
        anchors.fill: parent
        color: fc.trackBackground
        border.width: 1
        border.color: fc.borderMuted
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
            width: !batterySliderRoot.batteryAvailable ? 0 : parent.height + ((parent.width - parent.height) * (batterySliderRoot.batteryCapacity / 100))
            color: "#ffffff"
            radius: height / 2
            anchors.left: parent.left
            anchors.leftMargin: 0
            clip: true
            visible: batterySliderRoot.batteryAvailable

            // --- STATIC LEFT ICON (FOREGROUND OVERLAY) ---
            Text {
                id: fgIcon
                visible: batterySliderRoot.batteryAvailable && fillBar.width >= x
                text: bgIcon.text
                font.family: fc.iconFont
                font.pixelSize: 24
                color: fc.overlayForeground
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
                x: 49
                y: bgLabel.y
                text: batterySliderRoot.combinedText
                color: fc.overlayForeground
                font.family: fc.mainFont
                font.pixelSize: 13
                font.weight: Font.Bold
                Component.onCompleted: fc.applySmoothing(this)
            }
        }
    }
}