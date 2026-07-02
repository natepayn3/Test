import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

PanelWindow {
    id: bluetoothPopupWindow

    // --- Window Configuration ---
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

    // --- Global Theme Mapping ---
    property color colorBackground: shellConfig.colorBackground
    property color colorBorder: shellConfig.colorBorder

    // Internal flag managing the graceful scale/fade execution loop
    property bool animateActive: false

    // --- State Properties ---
    property bool isPowered: false
    property bool isScanning: false
    property bool isToggling: false
    property bool bootComplete: false

    property string activeStatusText: isScanning ? "Scanning..." : (isPowered ? "Bluetooth ON" : "Bluetooth OFF")

    onVisibleChanged: {
        if (visible) {
            cardContainerMouseArea.forceActiveFocus();
            stateFetcher.running = true;
            if (!deviceFetcher.running) deviceFetcher.running = true;
            bluetoothPopupWindow.animateActive = true; // Safe visibility cascade kickoff
        } else {
            deviceFetcher.running = false;
            scanDurationTimer.stop();
            bluetoothPopupWindow.animateActive = false;
        }
    }

    // --- Fullscreen Outside Dismiss Wrapper ---
    MouseArea {
        id: outsideDismiss
        anchors.fill: parent
        onClicked: bluetoothPopupWindow.animateActive = false // Initiates uniform collapse cycle

        // --- Main Visual Panel ---
        Rectangle {
            id: bgCard
            width: 360 
            height: Math.min(mainLayout.implicitHeight + 40, 500)
            transformOrigin: Item.Center
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 100
            anchors.horizontalCenter: parent.horizontalCenter
            
            color: bluetoothPopupWindow.colorBackground
            border.color: bluetoothPopupWindow.colorBorder
            border.width: 1
            radius: shellConfig.radiusValue

            // --- Standalone Left Side Bluetooth Icon ---
            Text {
                id: leftBluetoothIcon
                text: "bluetooth_searching"
                font.family: fc.iconFont
                font.pixelSize: 150
                color: bluetoothPopupWindow.colorBackground
                styleColor: colorBackground
                
                anchors.right: parent.left
                anchors.rightMargin: -15
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: 0
                rotation: -180
            }

            // --- Standalone Right Side Bluetooth Icon ---
            Text {
                id: rightBluetoothIcon
                text: "bluetooth_searching"
                font.family: fc.iconFont
                font.pixelSize: 150
                color: bluetoothPopupWindow.colorBackground
                styleColor: colorBackground

                anchors.left: parent.right
                anchors.leftMargin: -15
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: 0
            }

            // --- DECLARATIVE STATE ENGINE ---
            states: [
                State {
                    name: "hidden"
                    when: !bluetoothPopupWindow.animateActive
                    PropertyChanges { target: bgCard; opacity: 0.0; scale: 0.3 }
                },
                State {
                    name: "shown"
                    when: bluetoothPopupWindow.animateActive
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
                        // Securely clip layout visibility after animation finishes
                        ScriptAction { script: bluetoothPopupWindow.visible = false } 
                    }
                }
            ]

            MouseArea {
                id: cardContainerMouseArea
                anchors.fill: parent
                focus: true
                Keys.onEscapePressed: bluetoothPopupWindow.animateActive = false
                onClicked: (mouse) => mouse.accepted = true
            }

            ColumnLayout {
                id: mainLayout
                anchors.fill: parent
                anchors.margins: 22
                spacing: 20

                // --- Header Area ---
                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: "Bluetooth Devices"
                        color: "#ffffff"
                        font.family: "Google Sans Flex"
                        font.pixelSize: 18
                        font.weight: Font.Bold
                        style: Text.Outline
                        styleColor: Qt.rgba(0, 0, 0, 0.35)
                        Layout.fillWidth: true
                    }

                    MouseArea {
                        id: scanButton
                        width: 32
                        height: 32
                        hoverEnabled: true
                        enabled: bluetoothPopupWindow.isPowered
                        onClicked: bluetoothPopupWindow.triggerScan()

                        Rectangle {
                            anchors.fill: parent
                            radius: 8
                            color: parent.containsMouse ? Qt.rgba(255, 255, 255, 0.08) : "transparent"
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "radar"
                            font.family: "Material Symbols Outlined"
                            font.pixelSize: 22
                            color: "#ffffff"
                            opacity: bluetoothPopupWindow.isScanning ? 1.0 : 0.6
                            style: Text.Outline
                            styleColor: Qt.rgba(0, 0, 0, 0.35)
                        }
                    }
                }

                // --- Scrollable Device Layout Block ---
                ScrollView {
                    id: deviceScrollView
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                    ScrollBar.vertical.policy: ScrollBar.AsNeeded

                    ColumnLayout {
                        id: repeaterLayout
                        width: deviceScrollView.availableWidth
                        spacing: 8

                        Repeater {
                            id: deviceRepeater
                            model: ListModel { id: deviceModel }

                            delegate: Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 46
                                radius: 12
                                color: model.connected 
                                       ? Qt.rgba(255, 255, 255, 0.08) 
                                       : (delegateMouse.containsMouse ? Qt.rgba(255, 255, 255, 0.04) : "transparent")

                                MouseArea {
                                    id: delegateMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 14
                                    anchors.rightMargin: 14
                                    spacing: 12

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1
                                        
                                        Text {
                                            text: model.name !== "" ? model.name : model.mac
                                            color: "#ffffff"
                                            font.family: "Google Sans Flex"
                                            font.pixelSize: 14
                                            font.weight: model.connected ? Font.Bold : Font.Normal
                                            style: Text.Outline
                                            styleColor: Qt.rgba(0, 0, 0, 0.35)
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }

                                        Text {
                                            text: model.connected ? "Connected" : (model.paired ? "Paired" : model.mac)
                                            color: "#ffffff"
                                            opacity: model.connected ? 0.9 : 0.5
                                            font.family: "Google Sans Flex"
                                            font.pixelSize: 11
                                            style: Text.Outline
                                            styleColor: Qt.rgba(0, 0, 0, 0.35)
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }
                                    }

                                    MouseArea {
                                        id: linkAction
                                        Layout.preferredWidth: 32
                                        Layout.preferredHeight: 32
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (!model.paired) {
                                                bluetoothPopupWindow.pairDevice(model.mac);
                                            } else {
                                                bluetoothPopupWindow.handleDeviceClick(model.mac, model.connected);
                                            }
                                        }

                                        Rectangle {
                                            anchors.fill: parent
                                            radius: 6
                                            color: parent.containsMouse ? Qt.rgba(255, 255, 255, 0.08) : "transparent"
                                        }

                                        Text {
                                            anchors.centerIn: parent
                                            text: !model.paired ? "link" : (model.connected ? "link_off" : "cable")
                                            font.family: "Material Symbols Outlined"
                                            font.pixelSize: 18
                                            color: "#ffffff"
                                            style: Text.Outline
                                            styleColor: Qt.rgba(0, 0, 0, 0.35)
                                        }
                                    }

                                    MouseArea {
                                        id: removeAction
                                        Layout.preferredWidth: 32
                                        Layout.preferredHeight: 32
                                        visible: model.paired
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: bluetoothPopupWindow.removeDevice(model.mac)

                                        Rectangle {
                                            anchors.fill: parent
                                            radius: 6
                                            color: parent.containsMouse ? Qt.rgba(255, 255, 255, 0.08) : "transparent"
                                        }

                                        Text {
                                            anchors.centerIn: parent
                                            text: "delete"
                                            font.family: "Material Symbols Outlined"
                                            font.pixelSize: 18
                                            color: "#ffffff"
                                            opacity: 0.8
                                            style: Text.Outline
                                            styleColor: Qt.rgba(0, 0, 0, 0.35)
                                        }
                                    }
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

                // --- Footer / Status Row ---
                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: bluetoothPopupWindow.activeStatusText
                        font.family: "Google Sans Flex"
                        font.pixelSize: 14
                        color: "#ffffff"
                        opacity: 0.8
                        style: Text.Outline
                        styleColor: Qt.rgba(0, 0, 0, 0.35)
                        Layout.fillWidth: true
                    }

                    Switch {
                        id: powerSwitch
                        checked: bluetoothPopupWindow.isPowered
                        enabled: !bluetoothPopupWindow.isToggling
                        Layout.alignment: Qt.AlignVCenter
                        onClicked: bluetoothPopupWindow.togglePower()
                        
                        implicitWidth: 42
                        implicitHeight: 24
                        
                        indicator: Rectangle {
                            width: 42
                            height: 24
                            radius: 12
                            color: powerSwitch.checked ? Qt.rgba(0.4, 0.4, 0.4, 0.28) : "transparent"
                            border.color: powerSwitch.checked ? Qt.rgba(0.4, 0.4, 0.4, 0.28) : Qt.rgba(1, 1, 1, 0.2)
                            border.width: 2

                            Rectangle {
                                x: powerSwitch.checked ? parent.width - width - 4 : 4
                                anchors.verticalCenter: parent.verticalCenter
                                width: 14
                                height: 14
                                radius: 7
                                color: "#ffffff"
                                Behavior on x { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }
                            }
                        }
                    }
                }
            }
        }
    }

    // --- Backend Orchestration Drivers ---
    function syncDevices() {
        if (!visible) return;
        if (isPowered) {
            if (!deviceFetcher.running) deviceFetcher.running = true;
        } else {
            deviceModel.clear();
        }
    }

    function sortDeviceModel() {
        if (deviceModel.count <= 1) return;
        let items = [];
        for (let i = 0; i < deviceModel.count; i++) {
            let item = deviceModel.get(i);
            items.push({ mac: item.mac, name: item.name, connected: item.connected, paired: item.paired });
        }
        items.sort((a, b) => {
            if (a.connected !== b.connected) return a.connected ? -1 : 1;
            if (a.paired !== b.paired) return a.paired ? -1 : 1;
            return 0;
        });
        deviceModel.clear();
        for (let k = 0; k < items.length; k++) {
            deviceModel.append(items[k]);
        }
    }

    function triggerScan() {
        if (bluetoothPopupWindow.isScanning) {
            scanDurationTimer.stop();
            bluetoothPopupWindow.isScanning = false;
            bluetoothSession.write("scan off\n");
            Qt.callLater(() => { stateFetcher.running = true; }, 1000);
        } else {
            bluetoothPopupWindow.isScanning = true;
            bluetoothSession.write("scan on\n");
            scanDurationTimer.restart();
        }
    }

    function togglePower() {
        if (isToggling) return;
        isToggling = true;
        let targetState = !bluetoothPopupWindow.isPowered;
        bluetoothPopupWindow.isPowered = targetState;
        bluetoothSession.write(targetState ? "power on\n" : "power off\n");
        unlockTimer.restart();
    }

    function handleDeviceClick(mac, isConnected) {
        deviceActionProc.act(isConnected ? "disconnect" : "connect", mac);
    }

    function pairDevice(mac) { deviceActionProc.act("pair", mac); }
    function removeDevice(mac) { deviceActionProc.act("remove", mac); }

    Process {
        id: bluetoothSession
        command: ["/usr/bin/stdbuf", "-oL", "/usr/bin/bluetoothctl"]
        running: bluetoothPopupWindow.visible
        
        property int lastProcessedIndex: 0
        property string lineBuffer: ""

        onRunningChanged: {
            if (!running) {
                lastProcessedIndex = 0;
                lineBuffer = "";
            }
        }
        
        stdout: StdioCollector {
            onTextChanged: {
                let newChunk = this.text.substring(bluetoothSession.lastProcessedIndex);
                bluetoothSession.lastProcessedIndex = this.text.length;
                
                bluetoothSession.lineBuffer += newChunk;
                
                let lines = bluetoothSession.lineBuffer.split("\n");
                bluetoothSession.lineBuffer = lines.pop(); 
                
                let listNeedsSorting = false;
                for (let line of lines) {
                    let cleanLine = line.replace(/\x1b\[[0-9;]*[a-zA-Z]/g, "").trim();
                    if (cleanLine.includes("Pairing successful") || cleanLine.includes("Connection successful")) {
                        bluetoothPopupWindow.syncDevices();
                        continue;
                    }

                    if (cleanLine.includes("[NEW] Device")) {
                        let match = cleanLine.match(/Device\s+([0-9A-Fa-f:]{17})\s+(.*)/);
                        if (match) {
                            let mac = match[1];
                            let name = match[2].trim();
                            
                            let exists = false;
                            for (let j = 0; j < deviceModel.count; j++) {
                                if (deviceModel.get(j).mac === mac) { exists = true; break; }
                            }
                            if (!exists) {
                                deviceModel.append({ mac: mac, name: name, connected: false, paired: false });
                            }
                        }
                    }

                    if (cleanLine.includes("[CHG]")) {
                        let match = cleanLine.match(/Device\s+([0-9A-Fa-f:]{17})/);
                        if (match) {
                            let mac = match[1];
                            for (let j = 0; j < deviceModel.count; j++) {
                                if (deviceModel.get(j).mac === mac) {
                                    if (cleanLine.includes("Connected: yes") && !deviceModel.get(j).connected) {
                                        deviceModel.setProperty(j, "connected", true);
                                        listNeedsSorting = true;
                                    }
                                    if (cleanLine.includes("Connected: no") && deviceModel.get(j).connected) {
                                        deviceModel.setProperty(j, "connected", false);
                                        listNeedsSorting = true;
                                    }
                                    if (cleanLine.includes("Paired: yes") && !deviceModel.get(j).paired) {
                                        deviceModel.setProperty(j, "paired", true);
                                        listNeedsSorting = true;
                                    }
                                    break;
                                }
                            }
                        }
                    }
                }
                if (listNeedsSorting) bluetoothPopupWindow.sortDeviceModel();
            }
        }
    }

    Process {
        id: stateFetcher
        command: ["/usr/bin/bluetoothctl", "show"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                let textLines = this.text.split("\n");
                let isNowPowered = textLines.some(l => l.includes("Powered: yes"));
                let hardwareScanning = textLines.some(l => l.includes("Discovering: yes"));
                if (hardwareScanning && !bluetoothPopupWindow.isScanning) {
                    bluetoothPopupWindow.isScanning = true;
                    scanDurationTimer.restart(); 
                } else if (!hardwareScanning) {
                    bluetoothPopupWindow.isScanning = false;
                }
                
                if (bluetoothPopupWindow.isPowered !== isNowPowered) {
                    bluetoothPopupWindow.isPowered = isNowPowered;
                } else {
                    bluetoothPopupWindow.syncDevices();
                }
                bluetoothPopupWindow.isToggling = false;
            }
        }
    }

    Process {
        id: deviceFetcher
        command: [
            "/bin/bash", 
            "-c", 
            "bluetoothctl devices | grep '^Device ' | while read -r _ mac name; do info=$(bluetoothctl info \"$mac\"); [[ \"$info\" == *\"Paired: yes\"* ]] && paired='true' || paired='false'; [[ \"$info\" == *\"Connected: yes\"* ]] && conn='true' || conn='false'; echo \"$mac|$name|$conn|$paired\"; done"
        ]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                let lines = this.text.trim().split("\n");
                for (let i = 0; i < lines.length; i++) {
                    if (lines[i] === "") continue;
                    let parts = lines[i].split("|");
                    if (parts.length < 4) continue;

                    let mac = parts[0];
                    let name = parts[1].trim();
                    let isConnected = parts[2] === "true";
                    let isPaired = parts[3] === "true";
                    
                    if (name.includes("RSSI:") || name.includes("TxPower:")) continue;
                    let found = false;

                    for (let j = 0; j < deviceModel.count; j++) {
                        if (deviceModel.get(j).mac === mac) {
                            found = true;
                            deviceModel.setProperty(j, "connected", isConnected);
                            deviceModel.setProperty(j, "paired", isPaired);
                            if (name !== "" && deviceModel.get(j).name !== name) {
                                deviceModel.setProperty(j, "name", name);
                            }
                            break;
                        }
                    }

                    if (!found) {
                        deviceModel.append({ mac: mac, name: name, connected: isConnected, paired: isPaired });
                    }
                }
                bluetoothPopupWindow.sortDeviceModel();
            }
        }
    }

    Process {
        id: deviceActionProc
        running: false
        function act(mode, mac) {
            if (mode === "pair") {
                command = ["/bin/bash", "-c", "bluetoothctl trust " + mac + " && bluetoothctl pair " + mac];
            } else {
                command = ["bluetoothctl", mode, mac];
            }
            running = false;
            running = true;
        }
        onExited: {
            if (bluetoothPopupWindow.visible) bluetoothPopupWindow.syncDevices();
        }
    }

    Timer {
        id: liveScanTimer
        interval: 1500
        repeat: true
        running: bluetoothPopupWindow.isScanning
        onTriggered: if (!deviceFetcher.running) deviceFetcher.running = true;
    }

    Timer {
        id: scanDurationTimer
        interval: 5000
        repeat: false
        onTriggered: {
            bluetoothPopupWindow.isScanning = false;
            bluetoothSession.write("scan off\n");
            Qt.callLater(() => { stateFetcher.running = true; }, 2500);
        }
    }

    Timer {
        id: unlockTimer
        interval: 1000
        onTriggered: isToggling = false
    }
}
