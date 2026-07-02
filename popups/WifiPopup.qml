import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../configs"

PanelWindow {
    id: wifiPopupWindow

    // --- Window Configuration ---
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-launcher"
    WlrLayershell.keyboardFocus: visible ? WlrLayershell.OnDemand : WlrLayershell.None
    exclusionMode: ExclusionMode.Ignore

    property color colorBackground: shellConfig.colorBackground
    property color colorBorder: shellConfig.colorBorder

    // Internal flag to drive the animation states safely
    property bool animateActive: false

    anchors {
        bottom: true
        top: true
        left: true
        right: true
    }
    
    color: "transparent"

    // --- State Properties ---
    property bool hasHardware: false
    property bool isPowered: false
    property bool isScanning: false
    property string activeSsid: ""
    property string expandedSsid: ""
    property string connectingSsid: ""
    property string failedSsid: ""
    property var knownNetworks: ({})

    property string activeStatusText: !hasHardware 
        ? "No Wi-Fi adapter found"
        : (isScanning 
            ? "Scanning networks..." 
            : (isPowered ? (activeSsid !== "" ? "Connected to " + activeSsid : "Wi-Fi is ON") : "Wi-Fi is OFF"))

    FontConfig { id: fc }

    ListModel { id: wifiModel }

    // --- Fullscreen Outside Dismiss Area ---
    MouseArea {
        id: outsideDismiss
        anchors.fill: parent
        onClicked: wifiPopupWindow.animateActive = false // Trigger close animation instead of hard exit

        // --- Main Visual Panel ---
        Rectangle {
            id: bgCard
            width: shellConfig.panelWidth
            
            // Core Change: Bind height dynamically but wrap it in a smooth structural Behavior
            height: Math.min(mainLayout.implicitHeight + 40, 500)
            
            Behavior on height {
                NumberAnimation {
                    duration: shellConfig.durationOut // Uses the 200ms layout metric for snappy adjustments
                    easing.type: Easing.OutCubic
                }
            }
         
            transformOrigin: Item.Center
            anchors.bottom: parent.bottom
            anchors.bottomMargin: shellConfig.panelBottomMargin
            anchors.horizontalCenter: parent.horizontalCenter
            
            color: colorBackground
            border.color: colorBorder
            border.width: 1
      
            radius: shellConfig.radiusValue

            // --- Standalone Left Side Wifi Icon ---
            Text {
                id: leftWifiIcon
                text: "rss_feed"
                font.family: fc.iconFont
                font.pixelSize: 125
                color: fc.overlayBackground // Swapped hardcoded bg color for fontconfig overlay token
                styleColor: colorBackground
                
                anchors.right: parent.left
                anchors.rightMargin: 5
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: 0
                rotation: -135
                
                Component.onCompleted: fc.applySmoothing(this)
            }

            // --- Standalone Right Side Wifi Icon ---
            Text {
                id: rightWifiIcon
                text: "rss_feed"
                font.family: fc.iconFont
                font.pixelSize: 125
                color: fc.overlayBackground // Swapped hardcoded bg color for fontconfig overlay token
                styleColor: colorBackground

                anchors.left: parent.right
                anchors.leftMargin: 5
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: 0
                rotation: 45
                
                Component.onCompleted: fc.applySmoothing(this)
            }

            // --- DECLARATIVE STATE ENGINE ---
            states: [
               State {
                    name: "hidden"
                    when: !wifiPopupWindow.animateActive
                    PropertyChanges { target: bgCard; opacity: 0.0; scale: 0.3 }
                },
                State {
                    name: "shown"
                    when: wifiPopupWindow.animateActive
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
                        ScriptAction { script: wifiPopupWindow.visible = false } 
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
                spacing: 20

                // --- Header Zone ---
                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: "Wi-Fi Networks"
                        color: fc.textPrimary // Bind directly to centralized text color
                        font.family: shellConfig.shellFont
                        font.pixelSize: 18
                        font.weight: Font.Bold
                        Layout.fillWidth: true
                        
                        Component.onCompleted: fc.applyOutline(this) // Abstracted inline styling to the factory
                    }

                    Switch {
                        id: powerSwitch
                        checked: wifiPopupWindow.isPowered && wifiPopupWindow.hasHardware
                        enabled: wifiPopupWindow.hasHardware
                        opacity: wifiPopupWindow.hasHardware ? 1.0 : 0.4
                        Layout.alignment: Qt.AlignVCenter
                        onClicked: wifiPopupWindow.togglePowerState()
                        
                        implicitWidth: 42
                        implicitHeight: 24
                        
                        indicator: Rectangle {
                            width: 42
                            height: 24
                            radius: 12
                            color: powerSwitch.checked ? shellConfig.themeAccent : "transparent"
                            border.color: powerSwitch.checked ? shellConfig.themeAccent : fc.borderMuted // Using centralized transparent borders
                            border.width: 2

                            Rectangle {
                                x: powerSwitch.checked ? parent.width - width - 4 : 4
                                anchors.verticalCenter: parent.verticalCenter
                                width: 14
                                height: 14
                                radius: 7
                                color: fc.textPrimary // Swapped hardcoded reference
                                
                                Behavior on x { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }
                            }
                        }
                    }
                }

                // --- Connection Status Display ---
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12
                    opacity: wifiPopupWindow.hasHardware ? 1.0 : 0.4

                    Text {
                        text: !wifiPopupWindow.hasHardware ? "signal_wifi_off" : (wifiPopupWindow.isScanning ? "refresh" : "network_wifi")
                        font.family: fc.iconFont // Use uniform centralized font family
                        font.pixelSize: 22
                        color: fc.textPrimary // central text channel
                        
                        Component.onCompleted: fc.applyOutline(this)
                        
                        RotationAnimator on rotation {
                            running: wifiPopupWindow.isScanning && wifiPopupWindow.hasHardware
                            from: 0
                            to: 360
                            loops: Animation.Infinite
                            duration: 1200
                        }
                    }

                    Text {
                        text: wifiPopupWindow.activeStatusText
                        font.family: shellConfig.shellFont
                        font.pixelSize: 13
                        color: fc.textMuted // Secondary text channel instead of hardcoded opacity modifiers
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                        
                        Component.onCompleted: fc.applySmoothing(this)
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: shellConfig.colorBorder
                }

                // --- Network ListView Panel ---
                ListView {
                    id: networkListView
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredHeight: contentHeight
                    visible: wifiPopupWindow.isPowered && wifiPopupWindow.hasHardware
                    clip: true
                    model: wifiModel
                    spacing: 8

                    delegate: Item {
                        id: delegateRoot
                        property bool isExpanded: wifiPopupWindow.expandedSsid === model.ssid
                        property bool isKnown: wifiPopupWindow.knownNetworks[model.ssid] === true
                        property bool isConnecting: wifiPopupWindow.connectingSsid === model.ssid
                        property bool isFailed: wifiPopupWindow.failedSsid === model.ssid
                        
                        width: networkListView.width
                        height: isExpanded ? 96 : 44
                        Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                        Rectangle {
                            anchors.fill: parent
                            radius: 12
                            clip: true
                            color: model.connected 
                                ? shellConfig.themeAccent
                                : (itemMouse.containsMouse || isExpanded ? shellConfig.colorBorder : "transparent")
                            border.color: itemMouse.containsMouse || isExpanded ? shellConfig.hoverBorder : "transparent"
                            border.width: 1
                        }

                        ColumnLayout {
                            anchors.fill: parent
                            spacing: 0

                            Item {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 44

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 14
                                    anchors.rightMargin: 14
                                    spacing: 8

                                    Text {
                                        text: model.ssid
                                        color: fc.textPrimary
                                        font.family: shellConfig.shellFont
                                        font.pixelSize: 14
                                        font.weight: model.connected ? Font.Bold : Font.Normal
                                        opacity: model.connected ? 1.0 : 0.8
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                        
                                        Component.onCompleted: fc.applyOutline(this)
                                    }

                                    Text {
                                        text: {
                                            if (model.signalStrength > 75) return model.isSecure ? "network_wifi_locked" : "network_wifi";
                                            if (model.signalStrength > 50) return model.isSecure ? "network_wifi_3_bar_locked" : "network_wifi_3_bar";
                                            if (model.signalStrength > 25) return model.isSecure ? "network_wifi_2_bar_locked" : "network_wifi_2_bar";
                                            return model.isSecure ? "network_wifi_1_bar_locked" : "network_wifi_1_bar";
                                        }
                                        font.family: fc.iconFont
                                        font.pixelSize: 20
                                        color: model.connected ? fc.textPrimary : fc.textMuted
                                        
                                        Component.onCompleted: fc.applyOutline(this)
                                    }
                                }

                                MouseArea {
                                    id: itemMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    enabled: !isConnecting
                                    
                                    onClicked: {
                                        if (wifiPopupWindow.expandedSsid === model.ssid) {
                                            wifiPopupWindow.expandedSsid = "";
                                            wifiPopupWindow.failedSsid = "";
                                        } else {
                                            wifiPopupWindow.expandedSsid = model.ssid;
                                        }
                                    }
                                }
                            }

                            Item {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 44
                                visible: isExpanded
                                opacity: isExpanded ? 1.0 : 0.0
                                Behavior on opacity { NumberAnimation { duration: 150 } }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 14
                                    anchors.rightMargin: 14
                                    anchors.bottomMargin: 6
                                    spacing: 8

                                    RowLayout {
                                        Layout.fillWidth: true
                                        visible: model.connected
                                        spacing: 8

                                        Button {
                                            id: disconnectBtn
                                            text: "Disconnect"
                                            Layout.fillWidth: true
                                            onClicked: disconnectProc.disconnect(model.ssid)
                                            contentItem: Text { text: disconnectBtn.text; font.family: shellConfig.shellFont; font.pixelSize: 12; color: fc.textPrimary; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; Component.onCompleted: fc.applySmoothing(this) }
                                            background: Rectangle { radius: 8; color: disconnectBtn.hovered ? shellConfig.colorBackground : shellConfig.themeAccent; border.color: disconnectBtn.hovered ? shellConfig.hoverBorder : "transparent"; border.width: 1 }
                                        }
                                        Button {
                                            id: forgetActiveBtn
                                            text: "Forget"
                                            Layout.fillWidth: true
                                            onClicked: forgetProc.forget(model.ssid)
                                            contentItem: Text { text: forgetActiveBtn.text; font.family: shellConfig.shellFont; font.pixelSize: 12; color: fc.textPrimary; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; Component.onCompleted: fc.applySmoothing(this) }
                                            background: Rectangle { radius: 8; color: forgetActiveBtn.hovered ? shellConfig.colorBackground : shellConfig.themeAccent; border.color: forgetActiveBtn.hovered ? shellConfig.hoverBorder : "transparent"; border.width: 1 }
                                        }
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        visible: !model.connected && (isKnown || !model.isSecure)
                                        spacing: 8

                                        Button {
                                            id: connectBtn
                                            text: isConnecting ? "Connecting..." : (isFailed ? "Retry Connection" : "Connect")
                                            Layout.fillWidth: true
                                            enabled: !isConnecting
                                            onClicked: connectNetworkProc.connectTo(model.ssid, "", isKnown)
                                            contentItem: Text { text: connectBtn.text; font.family: shellConfig.shellFont; font.pixelSize: 12; color: fc.textPrimary; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; opacity: connectBtn.enabled ? 1.0 : 0.4; Component.onCompleted: fc.applySmoothing(this) }
                                            background: Rectangle { radius: 8; color: connectBtn.hovered ? shellConfig.colorBackground : shellConfig.themeAccent; border.color: connectBtn.hovered ? shellConfig.hoverBorder : "transparent"; border.width: 1 }
                                        }
                                        Button {
                                            id: forgetInactiveBtn
                                            text: "Forget"
                                            visible: isKnown
                                            Layout.preferredWidth: 90
                                            enabled: !isConnecting
                                            onClicked: forgetProc.forget(model.ssid)
                                            contentItem: Text { text: forgetInactiveBtn.text; font.family: shellConfig.shellFont; font.pixelSize: 12; color: fc.textPrimary; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; opacity: forgetInactiveBtn.enabled ? 1.0 : 0.4; Component.onCompleted: fc.applySmoothing(this) }
                                            background: Rectangle { radius: 8; color: forgetInactiveBtn.hovered ? shellConfig.colorBackground : shellConfig.themeAccent; border.color: forgetInactiveBtn.hovered ? shellConfig.hoverBorder : "transparent"; border.width: 1 }
                                        }
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        visible: !model.connected && !isKnown && model.isSecure
                                        spacing: 8

                                        Rectangle {
                                            Layout.fillWidth: true
                                            Layout.fillHeight: true
                                            radius: 8
                                            color: fc.trackBackground // Replaced hardcoded black overlay opacity mapping
                                            border.color: isFailed ? "#ff5555" : shellConfig.colorBorder
                                            border.width: 1

                                            TextInput {
                                                id: passInput
                                                anchors.fill: parent
                                                anchors.leftMargin: 10
                                                anchors.rightMargin: 10
                                                verticalAlignment: TextInput.AlignVCenter
                                                color: fc.textPrimary
                                                font.pixelSize: 13
                                                echoMode: TextInput.Password
                                                enabled: !isConnecting
                                                
                                                onAccepted: if (!isConnecting) connectNetworkProc.connectTo(model.ssid, passInput.text, false)
                                                onTextEdited: if (isFailed) wifiPopupWindow.failedSsid = ""

                                                Text {
                                                    text: "Password..."
                                                    color: fc.textMuted // Replaced hardcoded translucent white with textMuted
                                                    font.pixelSize: 13
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    visible: passInput.text === "" && !passInput.activeFocus
                                                    Component.onCompleted: fc.applySmoothing(this)
                                                }
                                            }
                                        }

                                        Button {
                                            id: joinBtn
                                            text: isConnecting ? "Wait..." : "Join"
                                            Layout.preferredWidth: 80
                                            enabled: !isConnecting
                                            onClicked: connectNetworkProc.connectTo(model.ssid, passInput.text, false)
                                            contentItem: Text { text: joinBtn.text; font.family: shellConfig.shellFont; font.pixelSize: 12; color: fc.textPrimary; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; opacity: joinBtn.enabled ? 1.0 : 0.4; Component.onCompleted: fc.applySmoothing(this) }
                                            background: Rectangle { radius: 8; color: joinBtn.hovered ? shellConfig.colorBackground : shellConfig.themeAccent; border.color: joinBtn.hovered ? shellConfig.hoverBorder : "transparent"; border.width: 1 }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        focus: true
        Keys.onEscapePressed: wifiPopupWindow.animateActive = false
    }

    // --- Core Network Infrastructure Logic ---
    function step1_fetchKnown() { fetchKnownProc.running = false; fetchKnownProc.running = true; }
    function step2_fetchCurrentSsid() { fetchCurrentSsidProc.running = false; fetchCurrentSsidProc.running = true; }
    function step3_fetchNetworks() { fetchNetworksProc.running = false; fetchNetworksProc.running = true; }
    function triggerRescan() { if (!isPowered || isScanning || !hasHardware) return; wifiPopupWindow.isScanning = true; scanNetworksProc.running = true; }
    function togglePowerState() { if (hasHardware) togglePowerProc.setPower(!isPowered); }

    Timer {
        id: hardwareScanDelay
        interval: 4000
        onTriggered: { wifiPopupWindow.isScanning = false; fetchStatusProc.running = true; }
    }

    Timer {
        id: statePollerTimer
        interval: 4000
        repeat: true
        running: wifiPopupWindow.visible
        triggeredOnStart: true
        onTriggered: {
            if (!togglePowerProc.running && !connectNetworkProc.running && !wifiPopupWindow.isScanning && !disconnectProc.running && wifiPopupWindow.expandedSsid === "") {
                fetchStatusProc.running = false;
                fetchStatusProc.running = true;
            }
        }
    }

    Process {
        id: fetchStatusProc
        command: ["sh", "-c", "nmcli dev | grep -q wifi && nmcli -t -f WIFI g"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                let cleaned = this.text.trim();
                if (cleaned === "" || cleaned.includes("not found")) {
                    wifiPopupWindow.hasHardware = false;
                    wifiPopupWindow.isPowered = false;
                    wifiPopupWindow.activeSsid = "";
                    wifiPopupWindow.expandedSsid = "";
                    wifiModel.clear();
                } else {
                    wifiPopupWindow.hasHardware = true;
                    wifiPopupWindow.isPowered = cleaned.includes("enabled");
                    if (wifiPopupWindow.isPowered) wifiPopupWindow.step1_fetchKnown();
                    else { wifiPopupWindow.activeSsid = ""; wifiPopupWindow.expandedSsid = ""; wifiPopupWindow.knownNetworks = {}; wifiModel.clear(); }
                }
            }
        }
    }

    Process {
        id: fetchKnownProc
        command: ["nmcli", "-t", "-f", "NAME,TYPE", "connection", "show"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                let lines = this.text.trim().split("\n");
                let dict = {};
                for (let i = 0; i < lines.length; i++) {
                    if (lines[i].trim() === "") continue;
                    let parts = lines[i].split(":");
                    if (parts.length >= 2) {
                        let type = parts.pop().trim();
                        let name = parts.join(":").trim();
                        if (type === "802-11-wireless") dict[name] = true;
                    }
                }
                wifiPopupWindow.knownNetworks = dict;
                wifiPopupWindow.step2_fetchCurrentSsid();
            }
        }
    }

    Process {
        id: fetchCurrentSsidProc
        command: ["nmcli", "-t", "-f", "ACTIVE,SSID", "dev", "wifi"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                let lines = this.text.split("\n");
                let foundActive = "";
                for (let i = 0; i < lines.length; i++) {
                    if (lines[i].startsWith("yes:")) { foundActive = lines[i].substring(4).trim(); break; }
                }
                wifiPopupWindow.activeSsid = foundActive;
                wifiPopupWindow.step3_fetchNetworks();
            }
        }
    }

    Process {
        id: fetchNetworksProc
        command: ["nmcli", "-t", "-f", "ACTIVE,BARS,SIGNAL,SECURITY,SSID", "dev", "wifi"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                let lines = this.text.split("\n");
                let uniqueList = [];
                for (let i = 0; i < lines.length; i++) {
                    let line = lines[i].trim();
                    if (line === "") continue;
                    
                    let parts = line.split(":");
                    if (parts.length < 5) continue;
                    
                    let isActive = parts[0].indexOf("yes") !== -1;
                    let bars = parts[1].trim();
                    let signal = parseInt(parts[2].trim()) || 0;
                    let securityStr = parts[3].trim();
                    let securityDisplay = (securityStr === "--" || securityStr === "") ? "Open" : securityStr;
                    let secureNode = (securityDisplay !== "Open");
                    let ssid = parts.slice(4).join(":").trim();
                    if (ssid === "") continue;
                    if (ssid === wifiPopupWindow.activeSsid) isActive = true;

                    let existingIndex = -1;
                    for (let n = 0; n < uniqueList.length; n++) {
                        if (uniqueList[n].ssid === ssid) { existingIndex = n; break; }
                    }
                    if (existingIndex === -1) {
                        uniqueList.push({ ssid: ssid, signalStrength: signal, barsString: bars, connected: isActive, isSecure: secureNode, securityType: securityDisplay });
                    } else {
                        if (isActive) uniqueList[existingIndex].connected = true;
                        if (secureNode) uniqueList[existingIndex].isSecure = true;
                        if (signal > uniqueList[existingIndex].signalStrength) {
                            uniqueList[existingIndex].signalStrength = signal;
                            uniqueList[existingIndex].barsString = bars;
                        }
                    }
                }
                let tempActiveList = [];
                let tempNormalList = [];
                for (let k = 0; k < uniqueList.length; k++) {
                    if (uniqueList[k].connected) tempActiveList.push(uniqueList[k]);
                    else tempNormalList.push(uniqueList[k]);
                }
                tempNormalList.sort((a, b) => b.signalStrength - a.signalStrength);
                let allNewItems = tempActiveList.concat(tempNormalList);
                for (let j = 0; j < allNewItems.length; j++) {
                    let newItem = allNewItems[j];
                    let foundIndex = -1;
                    for (let m = 0; m < wifiModel.count; m++) {
                        if (wifiModel.get(m).ssid === newItem.ssid) { foundIndex = m; break; }
                    }
                    if (foundIndex !== -1) {
                        let existing = wifiModel.get(foundIndex);
                        if (existing.signalStrength !== newItem.signalStrength) wifiModel.setProperty(foundIndex, "signalStrength", newItem.signalStrength);
                        if (existing.connected !== newItem.connected) wifiModel.setProperty(foundIndex, "connected", newItem.connected);
                        if (existing.isSecure !== newItem.isSecure) wifiModel.setProperty(foundIndex, "isSecure", newItem.isSecure);
                        if (foundIndex !== j) wifiModel.move(foundIndex, j, 1);
                    } else { wifiModel.insert(j, newItem); }
                }
                while (wifiModel.count > allNewItems.length) { wifiModel.remove(wifiModel.count - 1, 1); }
            }
        }
    }

    Process {
        id: scanNetworksProc
        command: ["nmcli", "dev", "wifi", "rescan"]
        running: false
        onRunningChanged: { if (!running && wifiPopupWindow.isScanning) hardwareScanDelay.restart(); }
    }

    Process {
        id: togglePowerProc
        running: false
        function setPower(turnOn) { command = ["nmcli", "radio", "wifi", turnOn ? "on" : "off"]; running = false; running = true; }
        onRunningChanged: { if (!running) fetchStatusProc.running = true; }
    }

    Process { id: cleanupFailedProc; running: false }

    Process {
        id: connectNetworkProc
        running: false
        property string attemptingSsid: ""
        function connectTo(ssidTarget, password, isKnown) {
            wifiPopupWindow.failedSsid = "";
            wifiPopupWindow.connectingSsid = ssidTarget;
            attemptingSsid = ssidTarget;
            running = false;
            let cleanPass = password.trim();
            if (isKnown) command = ["nmcli", "connection", "up", "id", ssidTarget];
            else if (cleanPass === "") command = ["nmcli", "dev", "wifi", "connect", ssidTarget];
            else command = ["nmcli", "dev", "wifi", "connect", ssidTarget, "password", cleanPass];
            running = true;
        }
        onExited: function(exitCode) {
            if (wifiPopupWindow.connectingSsid !== "") {
                if (exitCode !== 0) {
                    wifiPopupWindow.failedSsid = wifiPopupWindow.connectingSsid;
                    if (attemptingSsid !== "" && !wifiPopupWindow.knownNetworks[attemptingSsid]) {
                        cleanupFailedProc.command = ["nmcli", "connection", "delete", "id", attemptingSsid];
                        cleanupFailedProc.running = false;
                        cleanupFailedProc.running = true;
                    }
                } else { wifiPopupWindow.expandedSsid = ""; }
                wifiPopupWindow.connectingSsid = "";
                attemptingSsid = "";
                fetchStatusProc.running = true;
            }
        }
    }

    Process {
        id: disconnectProc
        running: false
        function disconnect(ssidTarget) { command = ["nmcli", "connection", "down", "id", ssidTarget]; running = false; running = true; }
        onRunningChanged: { if (!running) { fetchStatusProc.running = true; wifiPopupWindow.expandedSsid = ""; } }
    }

    Process {
        id: forgetProc
        running: false
        function forget(ssidTarget) { command = ["nmcli", "connection", "delete", "id", ssidTarget]; running = false; running = true; }
        onRunningChanged: { if (!running) { fetchStatusProc.running = true; wifiPopupWindow.expandedSsid = ""; } }
    }

    onVisibleChanged: {
        if (visible) {
            outsideDismiss.forceActiveFocus();
            fetchStatusProc.running = true;
            wifiPopupWindow.animateActive = true; // Kick off open animation when window initializes
        } else {
            wifiPopupWindow.animateActive = false;
        }
    }
}