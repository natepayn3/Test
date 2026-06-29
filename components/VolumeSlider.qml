import QtQuick
import QtQuick.Controls
import Quickshell.Io

Item {
    id: volumeSliderRoot
    width: parent.width
    height: 32

    property real currentVolume: 0.0

    Component.onCompleted: volFetcher.running = true

    Text {
        id: volIcon
        text: "volume_up"
        font.family: "Material Symbols Outlined"
        font.pixelSize: 20
        color: "#ffffff"
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
    }

    Slider {
        id: sliderControl
        anchors.left: volIcon.right
        anchors.right: parent.right
        anchors.leftMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        from: 0
        to: 1
        value: volumeSliderRoot.currentVolume

        onMoved: {
            volumeSliderRoot.currentVolume = value;
            setVolProc.command = ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", value.toFixed(2)];
            setVolProc.running = true;
        }

        background: Rectangle {
            x: sliderControl.leftPadding
            y: sliderControl.topPadding + sliderControl.availableHeight / 2 - height / 2
            width: sliderControl.availableWidth
            height: 8
            radius: 4
            color: Qt.rgba(1, 1, 1, 0.12)

            Rectangle {
                width: sliderControl.visualPosition * parent.width
                height: parent.height
                color: "#ffffff"
                radius: 4
            }
        }

        handle: Rectangle {
            x: sliderControl.leftPadding + sliderControl.visualPosition * (sliderControl.availableWidth - width)
            y: sliderControl.topPadding + sliderControl.availableHeight / 2 - height / 2
            width: 16
            height: 16
            radius: 8
            color: "#ffffff"
        }
    }

    Process { id: setVolProc; running: false }
    Process {
        id: volFetcher
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                let parts = this.text.trim().split(" ");
                if (parts.length >= 2) volumeSliderRoot.currentVolume = parseFloat(parts[1]);
                volFetcher.running = false;
            }
        }
    }
}