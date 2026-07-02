import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../configs"

PanelWindow {
    id: audioPopupWindow

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-launcher"
    WlrLayershell.keyboardFocus: visible ? WlrLayershell.OnDemand : WlrLayershell.None
    exclusionMode: ExclusionMode.Ignore

    anchors {
        bottom: true
        top: true
        left: true
        right: true
    }
    
    color: "transparent"

    property color colorBackground: shellConfig.colorBackground
    property color colorBorder: shellConfig.colorBorder

    property bool animateActive: false

    // --- State Properties ---
    property int systemVolume: 50
    property bool isMuted: false
    
    property int inputVolume: 50
    property bool isInputMuted: false

    MouseArea {
        id: outsideDismiss
        anchors.fill: parent
        onClicked: audioPopupWindow.animateActive = false 

        Rectangle {
            id: bgCard
            width: 360
            height: Math.min(mainLayout.implicitHeight + 40, 560) 
            transformOrigin: Item.Center
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 100
            anchors.horizontalCenter: parent.horizontalCenter
           
            color: audioPopupWindow.colorBackground
            border.color: audioPopupWindow.colorBorder
            border.width: 1
            radius: shellConfig.radiusValue

            Text {
                id: leftSpeakerIcon
                text: "speaker_2"
                font.family: fc.iconFont
                font.pixelSize: 200
                color: audioPopupWindow.colorBackground
                styleColor: colorBackground
             
                anchors.right: parent.left
                anchors.rightMargin: -35
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: 0
            }

            Text {
                id: rightSpeakerIcon
                text: "speaker_2"
                font.family: fc.iconFont
                font.pixelSize: 200
                color: audioPopupWindow.colorBackground
                styleColor: colorBackground

                anchors.left: parent.right
                anchors.leftMargin: -35
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: 0
            }

            states: [
                State {
                    name: "hidden"
                    when: !audioPopupWindow.animateActive
                    PropertyChanges { target: bgCard; opacity: 0.0; scale: 0.3 }
                },
                State {
                    name: "shown"
                    when: audioPopupWindow.animateActive
                    PropertyChanges { target: bgCard; opacity: 1.0; scale: 1.0 }
                }
            ]

            transitions: [
                Transition {
                    from: "hidden"; to: "shown"
                    ParallelAnimation {
                        NumberAnimation { target: bgCard; property: "scale"; duration: shellConfig.durationIn; easing.type: Easing.OutBack; easing.amplitude: shellConfig.springBack }
                        NumberAnimation { target: bgCard; property: "opacity"; duration: shellConfig.opacityIn; easing.type: Easing.OutQuad }
                    }
                },
                Transition {
                    from: "shown"; to: "hidden"
                    SequentialAnimation {
                        ParallelAnimation {
                            NumberAnimation { target: bgCard; property: "scale"; duration: shellConfig.durationOut; easing.type: Easing.InBack; easing.amplitude: shellConfig.springIn }
                            NumberAnimation { target: bgCard; property: "opacity"; duration: shellConfig.opacityOut; easing.type: Easing.InQuad }
                        }
                        ScriptAction { script: audioPopupWindow.visible = false } 
                    }
                }
            ]

            MouseArea {
                anchors.fill: parent
                onClicked: (mouse) => mouse.accepted = true
            }

            ColumnLayout {
                id: mainLayout
                anchors.fill: parent
                anchors.margins: 22
                spacing: 16

                // ==================== AUDIO OUTPUT SECTION ====================
                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: "Audio Output"
                        color: "#ffffff"
                        font.family: "Google Sans Flex"
                        font.pixelSize: 16
                        font.weight: Font.Bold
                        style: Text.Outline
                        styleColor: Qt.rgba(0, 0, 0, 0.35)
                        Layout.fillWidth: true
                    }

                    Text {
                        text: audioPopupWindow.isMuted ? "Muted" : audioPopupWindow.systemVolume + "%"
                        color: "#ffffff"
                        font.family: "Google Sans Flex"
                        font.pixelSize: 16
                        font.weight: Font.Bold
                        style: Text.Outline
                        styleColor: Qt.rgba(0, 0, 0, 0.35)
                        horizontalAlignment: Text.AlignRight
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 14

                    Text {
                        text: audioPopupWindow.isMuted ? "volume_off" : "volume_up"
                        font.family: fc.iconFont
                        font.pixelSize: 28
                        color: Qt.rgba(1, 1, 1, 0.9)
                        style: Text.Outline
                        styleColor: Qt.rgba(0, 0, 0, 0.35)

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                audioPopupWindow.isMuted = !audioPopupWindow.isMuted;
                                muteWriteProc.command = ["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"];
                                muteWriteProc.running = true;
                            }
                        }
                    }

                    Slider {
                        id: volumeSlider
                        Layout.fillWidth: true
                        from: 0
                        to: 100
                        value: audioPopupWindow.systemVolume

                        onMoved: {
                            audioPopupWindow.systemVolume = value;
                            if (audioPopupWindow.isMuted) audioPopupWindow.isMuted = false;
                            volumeWriteProc.command = ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", (value / 100).toFixed(2)];
                            volumeWriteProc.running = true;
                        }

                        background: Rectangle {
                            x: volumeSlider.leftPadding
                            y: volumeSlider.topPadding + volumeSlider.availableHeight / 2 - height / 2
                            implicitWidth: 200
                            implicitHeight: 6
                            width: volumeSlider.availableWidth
                            height: implicitHeight
                            radius: 3
                            color: Qt.rgba(1, 1, 1, 0.15)

                            Rectangle {
                                width: volumeSlider.visualPosition * parent.width
                                height: parent.height
                                color: audioPopupWindow.isMuted ? "#666666" : Qt.rgba(1, 1, 1, 0.85)
                                radius: 3
                            }
                        }

                        handle: Rectangle {
                            x: volumeSlider.leftPadding + volumeSlider.visualPosition * (volumeSlider.availableWidth - width)
                            y: volumeSlider.topPadding + volumeSlider.availableHeight / 2 - height / 2
                            implicitWidth: 16
                            implicitHeight: 16
                            radius: 8
                            color: audioPopupWindow.isMuted ? "#999999" : "#ffffff"
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Repeater {
                        id: sinkRepeater
                        model: ListModel { id: sinkModel }

                        delegate: MouseArea {
                            Layout.fillWidth: true
                            implicitHeight: 38
                            hoverEnabled: true
                            onClicked: {
                                sinkSetProc.command = ["wpctl", "set-default", model.sinkTarget];
                                sinkSetProc.running = true;
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
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12

                                Text {
                                    text: model.sinkName
                                    color: "#ffffff"
                                    font.family: "Google Sans Flex"
                                    font.pixelSize: 14
                                    font.weight: model.isDefault ? Font.DemiBold : Font.Normal
                                    opacity: model.isDefault ? 1.0 : 0.7
                                    style: Text.Outline
                                    styleColor: Qt.rgba(0, 0, 0, 0.35)
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }

                                Text {
                                    text: "check"
                                    font.family: fc.iconFont
                                    font.pixelSize: 18
                                    color: "#ffffff"
                                    opacity: 0.95
                                    style: Text.Outline
                                    styleColor: Qt.rgba(0, 0, 0, 0.35)
                                    visible: model.isDefault
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: Qt.rgba(1, 1, 1, 0.1)
                }

                // ==================== AUDIO INPUT SECTION ====================
                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: "Audio Input"
                        color: "#ffffff"
                        font.family: "Google Sans Flex"
                        font.pixelSize: 16
                        font.weight: Font.Bold
                        style: Text.Outline
                        styleColor: Qt.rgba(0, 0, 0, 0.35)
                        Layout.fillWidth: true
                    }

                    Text {
                        text: audioPopupWindow.isInputMuted ? "Muted" : audioPopupWindow.inputVolume + "%"
                        color: "#ffffff"
                        font.family: "Google Sans Flex"
                        font.pixelSize: 16
                        font.weight: Font.Bold
                        style: Text.Outline
                        styleColor: Qt.rgba(0, 0, 0, 0.35)
                        horizontalAlignment: Text.AlignRight
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 14

                    Text {
                        text: audioPopupWindow.isInputMuted ? "mic_off" : "mic"
                        font.family: fc.iconFont
                        font.pixelSize: 28
                        color: Qt.rgba(1, 1, 1, 0.9)
                        style: Text.Outline
                        styleColor: Qt.rgba(0, 0, 0, 0.35)

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                audioPopupWindow.isInputMuted = !audioPopupWindow.isInputMuted;
                                muteWriteProc.command = ["wpctl", "set-mute", "@DEFAULT_AUDIO_SOURCE@", "toggle"];
                                muteWriteProc.running = true;
                            }
                        }
                    }

                    Slider {
                        id: micSlider
                        Layout.fillWidth: true
                        from: 0
                        to: 100
                        value: audioPopupWindow.inputVolume

                        onMoved: {
                            audioPopupWindow.inputVolume = value;
                            if (audioPopupWindow.isInputMuted) audioPopupWindow.isInputMuted = false;
                            volumeWriteProc.command = ["wpctl", "set-volume", "@DEFAULT_AUDIO_SOURCE@", (value / 100).toFixed(2)];
                            volumeWriteProc.running = true;
                        }

                        background: Rectangle {
                            x: micSlider.leftPadding
                            y: micSlider.topPadding + micSlider.availableHeight / 2 - height / 2
                            implicitWidth: 200
                            implicitHeight: 6
                            width: micSlider.availableWidth
                            height: implicitHeight
                            radius: 3
                            color: Qt.rgba(1, 1, 1, 0.15)

                            Rectangle {
                                width: micSlider.visualPosition * parent.width
                                height: parent.height
                                color: audioPopupWindow.isInputMuted ? "#666666" : Qt.rgba(1, 1, 1, 0.85)
                                radius: 3
                            }
                        }

                        handle: Rectangle {
                            x: micSlider.leftPadding + micSlider.visualPosition * (micSlider.availableWidth - width)
                            y: micSlider.topPadding + micSlider.availableHeight / 2 - height / 2
                            implicitWidth: 16
                            implicitHeight: 16
                            radius: 8
                            color: audioPopupWindow.isInputMuted ? "#999999" : "#ffffff"
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Repeater {
                        id: sourceRepeater
                        model: ListModel { id: sourceModel }

                        delegate: MouseArea {
                            Layout.fillWidth: true
                            implicitHeight: 38
                            hoverEnabled: true
                            onClicked: {
                                sinkSetProc.command = ["wpctl", "set-default", model.sourceTarget];
                                sinkSetProc.running = true;
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
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12

                                Text {
                                    text: model.sourceName
                                    color: "#ffffff"
                                    font.family: "Google Sans Flex"
                                    font.pixelSize: 14
                                    font.weight: model.isDefault ? Font.DemiBold : Font.Normal
                                    opacity: model.isDefault ? 1.0 : 0.7
                                    style: Text.Outline
                                    styleColor: Qt.rgba(0, 0, 0, 0.35)
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }

                                Text {
                                    text: "check"
                                    font.family: fc.iconFont
                                    font.pixelSize: 18
                                    color: "#ffffff"
                                    opacity: 0.95
                                    style: Text.Outline
                                    styleColor: Qt.rgba(0, 0, 0, 0.35)
                                    visible: model.isDefault
                                }
                            }
                        }
                    }
                }
            }
        }

        focus: true
        Keys.onEscapePressed: audioPopupWindow.animateActive = false
    }

    // --- Backend Audio Pipeline Drivers ---
    Process {
        id: audioEventStream
        command: [
            "sh", "-c",
            "pactl subscribe | grep --line-buffered \"Event 'change' on sink\" | while read -r _; do wpctl get-volume @DEFAULT_AUDIO_SINK@; done"
        ]
        running: true
        stdout: SplitParser {
            onRead: data => {
                let cleaned = data.trim();
                if (!cleaned.startsWith("Volume:")) return;
                let currentMutedState = cleaned.includes("[MUTED]");
                let parts = cleaned.split(" ");
                let volVal = parseFloat(parts[1]);
                if (!isNaN(volVal) && !volumeSlider.pressed) {
                    audioPopupWindow.systemVolume = Math.round(volVal * 100);
                    audioPopupWindow.isMuted = currentMutedState;
                }
            }
        }
    }

    Process {
        id: micEventStream
        command: [
            "sh", "-c",
            "pactl subscribe | grep --line-buffered \"Event 'change' on source\" | while read -r _; do wpctl get-volume @DEFAULT_AUDIO_SOURCE@; done"
        ]
        running: true
        stdout: SplitParser {
            onRead: data => {
                let cleaned = data.trim();
                if (!cleaned.startsWith("Volume:")) return;
                let currentMutedState = cleaned.includes("[MUTED]");
                let parts = cleaned.split(" ");
                let volVal = parseFloat(parts[1]);
                if (!isNaN(volVal) && !micSlider.pressed) {
                    audioPopupWindow.inputVolume = Math.round(volVal * 100);
                    audioPopupWindow.isInputMuted = currentMutedState;
                }
            }
        }
    }

    Process {
        id: audioQueryProc
        command: ["wpctl", "status"]
        running: false
        
        stdout: StdioCollector {
            onStreamFinished: {
                let lines = this.text.split("\n");
                sinkModel.clear();
                sourceModel.clear();
                
                let seenSinkIds = {};
                let seenSourceIds = {};
                let targetBlock = 0;
                
                let hasDefaultSink = false;
                let hasDefaultSource = false;

                for (let i = 0; i < lines.length; i++) {
                    let line = lines[i];
                    if (line.includes("Sinks:")) { targetBlock = 1; continue; }
                    if (line.includes("Sources:")) { targetBlock = 2; continue; }
                    if (line.includes("Filters:") || line.includes("Streams:") || line.includes("Settings:")) { 
                        targetBlock = 0;
                    }

                    // If the line contains branch/leaf layout elements, it's a nested sub-node or client stream
                    if (line.includes("├─") || line.includes("└─")) {
                        continue;
                    }

                    let match = line.match(/(\*\s*)?\s*(\d+)\.\s+(.*)/);
                    if (match) {
                        let isDef = (match[1] !== undefined && match[1].includes("*"));
                        let id = match[2].trim();
                        let rawName = match[3].trim();
                        
                        // Clean off bracket properties (vol, muted) safely before checking content
                        let cleanName = rawName.split("[")[0].replace(/[├─└─│]/g, "").trim();
                        if (cleanName === "") continue;

                        if (targetBlock === 1) {
                            if (seenSinkIds[id]) continue;
                            seenSinkIds[id] = true;
                            
                            let finalDef = isDef && !hasDefaultSink;
                            if (finalDef) hasDefaultSink = true;

                            sinkModel.append({ isDefault: finalDef, sinkTarget: id, sinkName: cleanName });
                        } else if (targetBlock === 2) {
                            if (seenSourceIds[id]) continue;
                            seenSourceIds[id] = true;
                            
                            let finalDef = isDef && !hasDefaultSource;
                            if (finalDef) hasDefaultSource = true;

                            sourceModel.append({ isDefault: finalDef, sourceTarget: id, sourceName: cleanName });
                        }
                    }
                }
                audioQueryProc.queryAudioMetrics();
            }
        }

        function queryAudioMetrics() {
            volumeReadProc.running = true;
            micReadProc.running = true;
        }
    }

    Process {
        id: volumeReadProc
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                let cleaned = this.text.trim();
                let match = cleaned.match(/Volume:\s+([0-9.]+)/);
                if (match) {
                    audioPopupWindow.systemVolume = Math.round(parseFloat(match[1]) * 100);
                    audioPopupWindow.isMuted = cleaned.includes("[MUTED]");
                }
            }
        }
    }

    Process {
        id: micReadProc
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SOURCE@"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                let cleaned = this.text.trim();
                let match = cleaned.match(/Volume:\s+([0-9.]+)/);
                if (match) {
                    audioPopupWindow.inputVolume = Math.round(parseFloat(match[1]) * 100);
                    audioPopupWindow.isInputMuted = cleaned.includes("[MUTED]");
                }
            }
        }
    }

    Process { id: volumeWriteProc; running: false }
    Process { id: muteWriteProc; running: false }
    
    Process { 
        id: sinkSetProc
        running: false 
        onExited: audioQueryProc.running = true
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
        shellRoot.audioPopupActive = visible;
        if (visible) {
            outsideDismiss.forceActiveFocus();
            pollTimer.start();
            audioPopupWindow.animateActive = true;
        } else {
            pollTimer.stop();
            audioPopupWindow.animateActive = false;
        }
    }
}
