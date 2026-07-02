import QtQuick
import QtQuick.Controls
import Quickshell.Io
import "../../configs"

Item {
    id: brightnessSliderRoot
    width: parent.width
    height: 36

    property bool hasHardware: false
    property real currentBrightness: 0.0
    property string percentageText: hasHardware ? Math.round(brightnessSliderRoot.currentBrightness * 100) + "%" : "No Backlight"

    Component.onCompleted: brightFetcher.running = true

    FontConfig { id: fc }

    Rectangle {
        id: bgTrack
        anchors.fill: parent
        color: fc.trackBackground
        border.width: 1
        border.color: fc.borderMuted
        radius: height / 2
        clip: true
        opacity: brightnessSliderRoot.hasHardware ? 1.0 : 0.5

        // --- STATIC LEFT ICON (BACKGROUND) ---
        Text {
            id: bgIcon
            visible: !brightnessSliderRoot.hasHardware || fillBar.width < (x + width)
            text: !brightnessSliderRoot.hasHardware ? "brightness_empty" : (brightnessSliderRoot.currentBrightness < 0.4 ? "light_mode" : "brightness_high")
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
            visible: !brightnessSliderRoot.hasHardware || fillBar.width < (x + width)
            anchors.left: bgIcon.right
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: brightnessSliderRoot.percentageText
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
            width: !brightnessSliderRoot.hasHardware ? 0 : parent.height + ((parent.width - parent.height) * brightnessSliderRoot.currentBrightness)
            color: "#ffffff"
            radius: height / 2
            anchors.left: parent.left
            anchors.leftMargin: 0
            clip: true
            visible: brightnessSliderRoot.hasHardware

            // --- STATIC LEFT ICON (FOREGROUND OVERLAY) ---
            Text {
                id: fgIcon
                visible: brightnessSliderRoot.hasHardware && fillBar.width >= x
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
                visible: brightnessSliderRoot.hasHardware && fillBar.width >= x
                x: 49
                y: bgLabel.y
                text: brightnessSliderRoot.percentageText
                color: fc.overlayForeground
                font.family: fc.mainFont
                font.pixelSize: 13
                font.weight: Font.Bold
                Component.onCompleted: fc.applySmoothing(this)
            }
        }
    }

    MouseArea {
        id: dragArea
        anchors.fill: parent
        enabled: brightnessSliderRoot.hasHardware
        cursorShape: brightnessSliderRoot.hasHardware ? Qt.PointingHandCursor : Qt.ArrowCursor

        function updateBrightness(mouseX) {
            let trackWidth = width - height;
            let adjustedX = mouseX - (height / 2);
            let newPct = Math.max(0.0, Math.min(1.0, adjustedX / trackWidth));
            
            brightnessSliderRoot.currentBrightness = newPct;
            brightSetter.command = ["sh", "-c", "brightnessctl set " + Math.round(newPct * 100) + "%"];
            brightSetter.running = true;
        }

        onPositionChanged: (mouse) => {
            if (pressed) updateBrightness(mouse.x);
        }
        
        onClicked: (mouse) => {
            updateBrightness(mouse.x);
        }
    }

    Process { 
        id: brightSetter
        running: false 
    } 
    
    Process {
        id: brightFetcher
        command: ["sh", "-c", "if [ -d /sys/class/backlight ] && [ \"$(ls -A /sys/class/backlight 2>/dev/null)\" ]; then echo \"OK\"; echo $(brightnessctl get) $(brightnessctl max); else echo \"MISSING\"; fi 2>/dev/null"]
        running: false
    
        stdout: StdioCollector {
            onStreamFinished: {
                let lines = this.text.trim().split("\n")
                if (lines.length >= 2 && lines[0] === "OK") {
                    let parts = lines[1].split(" ")
                    if (parts.length >= 2) {
                        let current = parseFloat(parts[0])
                        let max = parseFloat(parts[1])
                        if (max > 0) {
                            brightnessSliderRoot.currentBrightness = current / max
                            brightnessSliderRoot.hasHardware = true
                        } else {
                            brightnessSliderRoot.hasHardware = false
                        }
                    }
                } else {
                    brightnessSliderRoot.hasHardware = false
                }
                brightFetcher.running = false
            }
        }
    }
}