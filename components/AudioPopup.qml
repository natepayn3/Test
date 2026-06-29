import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

PanelWindow {
    id: audioPopupWindow

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-launcher"
    WlrLayershell.keyboardFocus: visible ? WlrLayershell.OnDemand : WlrLayershell.None
    exclusionMode: ExclusionMode.Ignore

    // Expanding to the edges fixes the compositor canvas initialization bug
    anchors {
        bottom: true
        left: true
        right: true
    }
    
    margins {
        bottom: 90
    }

    // Window canvas fills screen width, but height stays perfectly dynamic
    implicitHeight: mainLayout.implicitHeight + 28
    color: "transparent"

    MouseArea {
        id: outsideDismiss
        anchors.fill: parent
        onClicked: audioPopupWindow.visible = false
    }

    // This clamps the visual box strictly to 260px right above the dock button
    Rectangle {
        id: bgCard
        width: 260
        height: parent.height
        anchors.horizontalCenter: parent.horizontalCenter
        
        // Semi-transparent background matrix to blend with the inherited blur
        color: Qt.rgba(0, 0, 0, 0.01)
        border.color: Qt.rgba(1, 1, 1, 0.1)
        border.width: 0
        radius: 12

        MouseArea {
            anchors.fill: parent
            onClicked: (mouse) => mouse.accepted = true
        }

        ColumnLayout {
            id: mainLayout
            anchors.fill: parent
            anchors.margins: 14
            spacing: 12

            Text {
                text: "Audio Outputs"
                color: "#ffffff"
                font.family: "Google Sans Flex"
                font.pixelSize: 14
                font.weight: Font.DemiBold
                style: Text.Outline
                styleColor: Qt.rgba(0, 0, 0, 0.35)
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Text {
                    text: "volume_up"
                    font.family: "Material Symbols Outlined"
                    font.pixelSize: 20
                    color: Qt.rgba(1, 1, 1, 0.8)
                    style: Text.Outline
                    styleColor: Qt.rgba(0, 0, 0, 0.35)
                }

                Slider {
                    id: volumeSlider
                    Layout.fillWidth: true
                    from: 0
                    to: 100
                    value: 50

                    onMoved: {
                        volumeWriteProc.command = ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", (value / 100).toFixed(2)];
                        volumeWriteProc.running = true;
                    }

                    background: Rectangle {
                        x: volumeSlider.leftPadding
                        y: volumeSlider.topPadding + volumeSlider.availableHeight / 2 - height / 2
                        implicitWidth: 200
                        implicitHeight: 4
                        width: volumeSlider.availableWidth
                        height: implicitHeight
                        radius: 2
                        color: Qt.rgba(1, 1, 1, 0.15)

                        Rectangle {
                            width: volumeSlider.visualPosition * parent.width
                            height: parent.height
                            color: Qt.rgba(1, 1, 1, 0.8)
                            radius: 2
                        }
                    }

                    handle: Rectangle {
                        x: volumeSlider.leftPadding + volumeSlider.visualPosition * (volumeSlider.availableWidth - width)
                        y: volumeSlider.topPadding + volumeSlider.availableHeight / 2 - height / 2
                        implicitWidth: 12
                        implicitHeight: 12
                        radius: 6
                        color: "#ffffff"
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Qt.rgba(1, 1, 1, 0.08)
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                Repeater {
                    id: sinkRepeater
                    model: []

                    delegate: MouseArea {
                        Layout.fillWidth: true
                        implicitHeight: 32
                        hoverEnabled: true
                        
                        onClicked: {
                            sinkSetProc.command = ["wpctl", "set-default", modelData.id];
                            sinkSetProc.running = true;
                            audioPopupWindow.visible = false;
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: 10
                            color: parent.containsMouse ? Qt.rgba(0.4, 0.4, 0.4, 0.28) : "transparent"
                            border.color: parent.containsMouse ? Qt.rgba(0, 0, 0, 0.2) : "transparent"
                            border.width: 1
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10

                            Text {
                                text: modelData.name
                                color: "#ffffff"
                                font.family: "Google Sans Flex"
                                font.pixelSize: 12
                                font.weight: modelData.isActive ? Font.Medium : Font.Normal
                                opacity: modelData.isActive ? 1.0 : 0.65
                                style: Text.Outline
                                styleColor: Qt.rgba(0, 0, 0, 0.35)
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }

                            Text {
                                text: "check"
                                font.family: "Material Symbols Outlined"
                                font.pixelSize: 14
                                color: "#ffffff"
                                opacity: 0.9
                                style: Text.Outline
                                styleColor: Qt.rgba(0, 0, 0, 0.35)
                                visible: modelData.isActive
                            }
                        }
                    }
                }
            }
        }
    }

    Keys.onEscapePressed: audioPopupWindow.visible = false

    Process {
        id: audioQueryProc
        command: ["fish", "-c", "wpctl status | sed -n '/Audio/,/Video/p' | sed -n '/Sinks:/,/Sources:/p' | grep -E '[0-9]+\\.'"]
        running: false
        stdout: SplitParser {
            onRead: data => {
                let lines = data.trim().split("\n");
                let parsedSinks = [];

                for (let line of lines) {
                    let cleaned = line.replace(/[├└│─•]/g, "").trim();
                    let match = cleaned.match(/(\*)?\s*([0-9]+)\.\s+(.+)/);
                    if (match) {
                        let isActive = match[1] === "*";
                        let id = match[2];
                        let name = match[3];
                        
                        name = name.replace(/\[vol:\s*[0-9.]+( MUTED)?\]/, "").trim();
                        
                        parsedSinks.push({ id: id, name: name, isActive: isActive });
                    }
                }
                sinkRepeater.model = parsedSinks;
                audioQueryProc.queryVolume();
            }
        }

        function queryVolume() {
            volumeReadProc.running = true;
        }
    }

    Process {
        id: volumeReadProc
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
        running: false
        stdout: SplitParser {
            onRead: data => {
                let match = data.trim().match(/Volume:\s+([0-9.]+)/);
                if (match) {
                    volumeSlider.value = Math.round(parseFloat(match[1]) * 100);
                }
            }
        }
    }

    Process { id: volumeWriteProc; running: false }
    
    Process { 
        id: sinkSetProc
        running: false 
        onExited: pollTimer.restart() 
    }

    Timer {
        id: pollTimer
        interval: 3000
        running: audioPopupWindow.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: audioQueryProc.running = true
    }

    onVisibleChanged: {
        if (visible) {
            pollTimer.start();
            audioPopupWindow.forceActiveFocus();
        } else {
            pollTimer.stop();
        }
    }
}