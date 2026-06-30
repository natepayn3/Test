import QtQuick
import QtQuick.Controls
import Quickshell.Io

Item {
    id: brightnessSliderRoot
    width: parent.width
    height: 48

    property bool hasHardware: false
    property real currentBrightness: 0.0
    property string percentageText: hasHardware ? Math.round(brightnessSliderRoot.currentBrightness * 100) + "%" : "No Backlight"

    // Unified opacity scaling applied to the root frame
    opacity: hasHardware ? 1.0 : 0.5

    Component.onCompleted: brightFetcher.running = true

    FontConfig { id: fc }

    Rectangle {
        id: bgTrack
        anchors.fill: parent
        color: Qt.rgba(1, 1, 1, 0.05)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.03)
        radius: height / 2
        clip: true

        Text {
            anchors.centerIn: parent
            text: brightnessSliderRoot.percentageText
            color: Qt.rgba(1, 1, 1, 0.35)
            font.family: fc.mainFont
            font.pixelSize: 13
            font.weight: Font.Bold
            Component.onCompleted: fc.applyOutline(this, Qt.rgba(0, 0, 0, 0.35))
        }

        Rectangle {
            id: fillBar
            height: parent.height
            width: !brightnessSliderRoot.hasHardware ? parent.height : parent.height + ((parent.width - parent.height) * brightnessSliderRoot.currentBrightness)
            color: "#ffffff"
            radius: height / 2
            anchors.left: parent.left
            anchors.leftMargin: 0
            opacity: 1.0
            clip: true 

            Text {
                x: (brightnessSliderRoot.width - width) / 2 - fillBar.anchors.leftMargin
                y: (brightnessSliderRoot.height - height) / 2
                text: brightnessSliderRoot.percentageText
                color: Qt.rgba(0, 0, 0, 0.85)
                font.family: fc.mainFont
                font.pixelSize: 13
                font.weight: Font.Bold
                Component.onCompleted: fc.applySmoothing(this)
            }
        }

        Text {
            id: bgIcon
            text: !brightnessSliderRoot.hasHardware ? "brightness_empty" : (brightnessSliderRoot.currentBrightness < 0.4 ? "light_mode" : "brightness_high")
            font.family: fc.iconFont
            font.pixelSize: 18
            color: Qt.rgba(1, 1, 1, 0.4)
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            Component.onCompleted: fc.applyOutline(this, Qt.rgba(0, 0, 0, 0.35))
        }

        Item {
            height: parent.height
            width: fillBar.width
            clip: true

            Text {
                text: !brightnessSliderRoot.hasHardware ? "brightness_empty" : (brightnessSliderRoot.currentBrightness < 0.4 ? "light_mode" : "brightness_high")
                font.family: fc.iconFont
                font.pixelSize: 18
                color: Qt.rgba(0, 0, 0, 0.75)
                x: 16
                anchors.verticalCenter: parent.verticalCenter
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

    Process { id: brightSetter; running: false } 
    
    Process {
        id: brightFetcher
        // First strictly verifies if a non-empty backlight class folder exists, then queries metrics
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