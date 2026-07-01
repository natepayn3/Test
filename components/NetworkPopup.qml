import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt.labs.folderlistmodel
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

PanelWindow {
    id: networkPopupWindow

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-launcher"
    // Handles top-level keyboard routing allocations on demand
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

    // --- State Properties ---
    property bool animateActive: false
    property string activeVpnName: ""
    property string publicIpAddress: ""
    property bool textVisible: true
    property bool hasImportError: false
    property bool showFileBrowser: false
    property string currentBrowserPath: "file://" + Quickshell.env("HOME")

    // --- Live Bandwidth Properties ---
    property string downloadSpeed: "0 B/s"
    property string uploadSpeed: "0 B/s"
    property var lastRxBytes: 0
    property var lastTxBytes: 0
    property var lastTime: 0
    
    property real lastCombinedSpeed: -1.0
    property var lastTextUpdateTime: 0
    
    property int maxGraphPoints: 50
    property real maxGraphCeiling: 10 * 1024 * 1024 

    FontConfig { id: fc }
    ModuleConfig { id: shellConfig }

    ListModel { id: vpnListModel }
    ListModel { id: graphHistoryModel }

    Timer {
        id: syncVpnTimer
        interval: 3000
        running: networkPopupWindow.visible && !showFileBrowser
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            vpnListPopulator.running = false;
            vpnListPopulator.running = true;
        }
    }

    // --- Real-Time Stream Parser ---
    Process {
        id: bandwidthStreamProc
        command: ["fish", "-c", "
            set dev (ip route show | awk '/default/ {print $5}' | head -n1)
            while true
                cat /proc/net/dev | grep \"$dev\"
                sleep 0.1
            end
        "]
        running: networkPopupWindow.visible
        
        stdout: SplitParser {
            onRead: data => {
                let formatBytes = function(bytes) {
                    if (bytes < 1024) return bytes.toFixed(0) + " B/s";
                    if (bytes < 1048576) return (bytes / 1024).toFixed(1) + " KB/s";
                    return (bytes / 1048576).toFixed(1) + " MB/s";
                };

                let textStr = data.trim();
                if (!textStr) return;
                
                let rawLineParts = textStr.split(":");
                if (rawLineParts.length < 2) return;
                
                let parts = rawLineParts[1].trim().split(/\s+/);
                if (parts.length < 9) return;

                let rx = parseInt(parts[0]); 
                let tx = parseInt(parts[8]); 
                let now = Date.now();

                if (networkPopupWindow.lastTime > 0) {
                    let elapsed = (now - networkPopupWindow.lastTime) / 1000;
                    if (elapsed > 0) {
                        let rxSpeed = (rx - networkPopupWindow.lastRxBytes) / elapsed;
                        let txSpeed = (tx - networkPopupWindow.lastTxBytes) / elapsed;
                        
                        if (now - networkPopupWindow.lastTextUpdateTime >= 1000) {
                            networkPopupWindow.downloadSpeed = formatBytes(rxSpeed);
                            networkPopupWindow.uploadSpeed = formatBytes(txSpeed);
                            networkPopupWindow.lastTextUpdateTime = now;
                        }

                        let combinedSpeed = rxSpeed + txSpeed;

                        if (combinedSpeed !== networkPopupWindow.lastCombinedSpeed) {
                            graphHistoryModel.append({ "speedValue": combinedSpeed });
                            if (graphHistoryModel.count > networkPopupWindow.maxGraphPoints) {
                                graphHistoryModel.remove(0);
                            }
                            networkPopupWindow.lastCombinedSpeed = combinedSpeed;
                        }
                    }
                }

                networkPopupWindow.lastRxBytes = rx;
                networkPopupWindow.lastTxBytes = tx;
                networkPopupWindow.lastTime = now;
            }
        }
    }

    MouseArea {
        id: outsideDismiss
        anchors.fill: parent
        onClicked: networkPopupWindow.animateActive = false 

        // FIXED: Focus and Escape keys are attached to the MouseArea item scopes
        focus: true
        Keys.onEscapePressed: networkPopupWindow.animateActive = false

        Rectangle {
            id: bgCard
            width: shellConfig.panelWidth
            height: networkPopupWindow.showFileBrowser ? 480 : (mainLayout.implicitHeight + 44)
            
            Behavior on height {
                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
            }
            
            transformOrigin: Item.Center
            anchors.bottom: parent.bottom
            anchors.bottomMargin: shellConfig.panelBottomMargin
            anchors.horizontalCenter: parent.horizontalCenter
            
            color: shellConfig.colorBackground
            border.color: shellConfig.colorBorder
            border.width: 1
            radius: shellConfig.radiusValue

            Text {
                id: leftNetworkIcon
                text: "arrow_cool_down"
                font.family: fc.iconFont
                font.pixelSize: 125
                color: shellConfig.colorBackground
                styleColor: colorBackground
             
                anchors.right: parent.left
                anchors.rightMargin: -20
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: 0
            }

            Text {
                id: rightNetworkIcon
                text: "arrow_warm_up"
                font.family: fc.iconFont
                font.pixelSize: 125
                color: shellConfig.colorBackground
                styleColor: colorBackground

                anchors.left: parent.right
                anchors.leftMargin: -20
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: 0
            }

            states: [
                State {
                    name: "hidden"
                    when: !networkPopupWindow.animateActive
                    PropertyChanges { target: bgCard; opacity: 0.0; scale: 0.3 }
                },
                State {
                    name: "shown"
                    when: networkPopupWindow.animateActive
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
                        ScriptAction { script: networkPopupWindow.visible = false } 
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

                // ==================== DASHBOARD PANEL ====================
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: !networkPopupWindow.showFileBrowser
                    spacing: 16
                    visible: !networkPopupWindow.showFileBrowser

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "Network Manager"
                            color: shellConfig.themeText
                            font.family: shellConfig.shellFont
                            font.pixelSize: 18
                            font.weight: Font.Bold
                            style: Text.Outline
                            styleColor: Qt.rgba(0, 0, 0, 0.35)
                            Layout.fillWidth: true
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        
                        Item { Layout.fillWidth: true }
                        
                        ColumnLayout {
                            spacing: 2
                            Layout.preferredWidth: 110
                            Text { text: "Download"; font.family: shellConfig.shellFont; font.pixelSize: 14; color: Qt.rgba(1, 1, 1, 0.5); horizontalAlignment: Text.AlignHCenter; Layout.fillWidth: true; style: Text.Outline; styleColor: Qt.rgba(0, 0, 0, 0.35) }
                            Text { text: networkPopupWindow.downloadSpeed; font.family: shellConfig.shellFont; font.pixelSize: 18; font.weight: Font.Bold; color: shellConfig.themeText; horizontalAlignment: Text.AlignHCenter; Layout.fillWidth: true; style: Text.Outline; styleColor: Qt.rgba(0, 0, 0, 0.35) }
                        }
                        
                        Item { Layout.fillWidth: true; Layout.minimumWidth: 40 }
                        
                        ColumnLayout {
                            spacing: 2
                            Layout.preferredWidth: 110
                            Text { text: "Upload"; font.family: shellConfig.shellFont; font.pixelSize: 14; color: Qt.rgba(1, 1, 1, 0.5); horizontalAlignment: Text.AlignHCenter; Layout.fillWidth: true; style: Text.Outline; styleColor: Qt.rgba(0, 0, 0, 0.35) }
                            Text { text: networkPopupWindow.uploadSpeed; font.family: shellConfig.shellFont; font.pixelSize: 18; font.weight: Font.Bold; color: shellConfig.themeText; horizontalAlignment: Text.AlignHCenter; Layout.fillWidth: true; style: Text.Outline; styleColor: Qt.rgba(0, 0, 0, 0.35) }
                        }
                        
                        Item { Layout.fillWidth: true }
                    }

                    // --- Real-Time Floating Wave Graph ---
                    Item {
                        id: sparklineCanvasWrapper
                        Layout.fillWidth: true
                        height: 44
                        visible: graphHistoryModel.count > 1

                        Shape {
                            anchors.fill: parent
                            layer.enabled: true
                            layer.samples: 4

                            ShapePath {
                                fillColor: "transparent"
                                strokeColor: "#ffffff"
                                strokeWidth: 1.75
                                capStyle: ShapePath.RoundCap
                                joinStyle: ShapePath.RoundJoin

                                PathPolyline {
                                    path: {
                                        let pointsList = [];
                                        let totalPoints = graphHistoryModel.count;
                                        if (totalPoints < 2) return pointsList;

                                        let availableWidth = sparklineCanvasWrapper.width;
                                        let availableHeight = sparklineCanvasWrapper.height;

                                        for (let i = 0; i < totalPoints; i++) {
                                            let nodeValue = graphHistoryModel.get(i).speedValue;
                                            
                                            let clampedValue = Math.min(nodeValue, networkPopupWindow.maxGraphCeiling);
                                            let scaleRatio = clampedValue / networkPopupWindow.maxGraphCeiling;

                                            let coordX = (i / (totalPoints - 1)) * availableWidth;
                                            let coordY = availableHeight - (scaleRatio * availableHeight);
                                            pointsList.push(Qt.point(coordX, coordY));
                                        }
                                        return pointsList;
                                    }
                                }
                            }
                        }
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: shellConfig.colorBorder }

                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "VPN Profiles"; font.family: shellConfig.shellFont; font.pixelSize: 14; font.bold: true; color: shellConfig.themeText; Layout.fillWidth: true; style: Text.Outline; styleColor: Qt.rgba(0, 0, 0, 0.35) }
                        
                        Button {
                            id: importBtn
                            flat: true
                            implicitWidth: 120
                            implicitHeight: 30
                            background: Rectangle {
                                radius: 8
                                color: importBtn.hovered ? Qt.rgba(0.4, 0.4, 0.4, 0.28) : "transparent"
                                border.color: importBtn.hovered ? Qt.rgba(0, 0, 0, 0.2) : "transparent"
                                border.width: 1
                            }
                            contentItem: Text { text: "+ Import"; font.family: shellConfig.shellFont; font.pixelSize: 12; font.bold: true; color: shellConfig.themeText; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; style: Text.Outline; styleColor: Qt.rgba(0, 0, 0, 0.35) }
                            onClicked: { networkPopupWindow.hasImportError = false; networkPopupWindow.showFileBrowser = true; }
                        }
                    }

                    ListView {
                        id: profileListView
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        implicitHeight: Math.min(vpnListModel.count * 68, 140)
                        spacing: 8
                        clip: true
                        model: vpnListModel

                        delegate: MouseArea {
                            id: profileItemDelegate
                            width: profileListView.width
                            height: 60
                            hoverEnabled: true

                            Rectangle {
                                anchors.fill: parent
                                radius: 10
                                
                                // Neutral alpha-blending that highlights the active profile without solid colors
                                color: networkPopupWindow.activeVpnName === profileName 
                                    ? Qt.rgba(1, 1, 1, 0.14) // Clean soft glare when connected
                                    : (parent.containsMouse ? Qt.rgba(0.4, 0.4, 0.4, 0.28) : "transparent")
                                
                                // Soft white border ring for connected profiles, subtle dark ring on hover
                                border.color: networkPopupWindow.activeVpnName === profileName 
                                    ? Qt.rgba(1, 1, 1, 0.35) 
                                    : (parent.containsMouse ? Qt.rgba(0, 0, 0, 0.2) : "transparent")
                                border.width: 1
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 12

                                Text {
                                    text: "vpn_key"
                                    font.family: "Material Symbols Outlined"
                                    font.pixelSize: 18
                                    
                                    // Stays pure white when connected, muted translucent gray when disconnected
                                    color: networkPopupWindow.activeVpnName === profileName 
                                        ? "#ffffff" 
                                        : Qt.rgba(1, 1, 1, 0.4)
                                }

                                ColumnLayout {
                                    spacing: 1
                                    Layout.fillWidth: true
                                    Text { text: profileName; font.family: shellConfig.shellFont; font.bold: true; font.pixelSize: 13; color: shellConfig.themeText; elide: Text.ElideRight }
                                    Text { text: networkPopupWindow.activeVpnName === profileName ? "Connected" : "Disconnected"; font.family: shellConfig.shellFont; font.pixelSize: 11; color: Qt.rgba(1,1,1,0.5) }
                                }

                                Switch {
                                    id: itemToggleSwitch
                                    checked: networkPopupWindow.activeVpnName === profileName
                                    onClicked: networkPopupWindow.toggleProfileState(profileName, checked)
                                    
                                    background: Rectangle {
                                        implicitWidth: 40
                                        implicitHeight: 20
                                        radius: 10
                                        
                                        // Soft white blend when checked, dark transparent frame when idle
                                        color: itemToggleSwitch.checked 
                                            ? Qt.rgba(1, 1, 1, 0.25) 
                                            : Qt.rgba(1, 1, 1, 0.1)
                                        
                                        border.color: itemToggleSwitch.checked ? Qt.rgba(1, 1, 1, 0.2) : "transparent"
                                        border.width: 1

                                        // The Slider Knob/Thumb
                                        Rectangle {
                                            width: 14
                                            height: 14
                                            radius: 7
                                            
                                            // Crisp white when active, muted gray when disabled (no accent colors)
                                            color: itemToggleSwitch.checked ? "#ffffff" : Qt.rgba(1, 1, 1, 0.4)
                                            
                                            anchors.verticalCenter: parent.verticalCenter
                                            x: itemToggleSwitch.checked ? 22 : 4
                                            Behavior on x { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                                        }
                                    }
                                    indicator: Item {}
                                }

                                Button {
                                    id: delBtn
                                    flat: true
                                    implicitWidth: 28; implicitHeight: 28
                                    
                                    // Soft, translucent white highlight on hover instead of red tint
                                    background: Rectangle { 
                                        color: delBtn.hovered ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
                                        radius: 6 
                                    }
                                    
                                    contentItem: Text { 
                                        text: "delete"
                                        font.family: "Material Symbols Outlined"
                                        font.pixelSize: 16
                                        
                                        // Bright white on hover, muted gray when idle
                                        color: delBtn.hovered ? "#ffffff" : Qt.rgba(1, 1, 1, 0.4)
                                        
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter 
                                    }
                                    onClicked: networkPopupWindow.deleteProfile(profileName)
                                }
                            }
                        }
                    }
                }

                // ==================== FILE BROWSER PANEL ====================
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: networkPopupWindow.showFileBrowser
                    spacing: 12
                    visible: networkPopupWindow.showFileBrowser

                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "Select VPN config:"; font.family: shellConfig.shellFont; font.pixelSize: 14; font.bold: true; color: shellConfig.themeText; Layout.fillWidth: true; style: Text.Outline; styleColor: Qt.rgba(0, 0, 0, 0.35) }
                        Button {
                            id: cancelBtn; flat: true; implicitWidth: 70; implicitHeight: 28
                            background: Rectangle { color: cancelBtn.hovered ? Qt.rgba(0.4, 0.4, 0.4, 0.28) : "transparent"; border.color: cancelBtn.hovered ? Qt.rgba(0, 0, 0, 0.2) : "transparent"; border.width: 1; radius: 6 }
                            contentItem: Text { text: "Cancel"; font.family: shellConfig.shellFont; font.pixelSize: 12; color: Qt.rgba(1,1,1,0.6); horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; style: Text.Outline; styleColor: Qt.rgba(0, 0, 0, 0.35) }
                            onClicked: networkPopupWindow.showFileBrowser = false
                        }
                    }

                    Text { text: networkPopupWindow.currentBrowserPath.replace("file://", ""); font.family: shellConfig.shellFont; font.pixelSize: 11; color: shellConfig.themeText; elide: Text.ElideLeft; Layout.fillWidth: true; style: Text.Outline; styleColor: Qt.rgba(0, 0, 0, 0.35) }

                    Rectangle {
                        Layout.fillWidth: true; Layout.fillHeight: true; color: Qt.rgba(0, 0, 0, 0.15); radius: 10; border.color: shellConfig.colorBorder; border.width: 1; clip: true

                        Item {
                            id: browserViewContainer; anchors.fill: parent
                            property string pendingPath: ""
                            property string lastPath: ""

                            ListView {
                                id: fileListView
                                anchors.fill: parent
                                anchors.margins: 6
                                spacing: 4
                                clip: true
                                model: FolderListModel {
                                    id: folderModel
                                    folder: networkPopupWindow.currentBrowserPath
                                    showDirsFirst: true
                                    showDotAndDotDot: true
                                    
                                    // EXPANDED FILTER: Tells the layout engine to reveal all target profile types
                                    nameFilters: ["*.conf", "*.ovpn", "*.vpn"] 
                                }
                                delegate: MouseArea {
                                    id: fileDelegateItem; width: fileListView.width; height: fileName === "." ? 0 : 34; visible: fileName !== "."
                                    hoverEnabled: true

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: 6
                                        color: parent.containsMouse ? Qt.rgba(0.4, 0.4, 0.4, 0.28) : "transparent"
                                        border.color: parent.containsMouse ? Qt.rgba(0, 0, 0, 0.2) : "transparent"
                                        border.width: 1
                                    }

                                    RowLayout {
                                        spacing: 8; anchors.fill: parent; anchors.leftMargin: 6
                                        Text { text: fileIsDir ? "folder" : "description"; font.family: "Material Symbols Outlined"; font.pixelSize: 16; color: shellConfig.themeText; style: Text.Outline; styleColor: Qt.rgba(0, 0, 0, 0.35) }
                                        Text { text: fileName; font.family: shellConfig.shellFont; font.pixelSize: 13; color: shellConfig.themeText; Layout.fillWidth: true; style: Text.Outline; styleColor: Qt.rgba(0, 0, 0, 0.35) }
                                    }

                                    onClicked: {
                                        if (fileIsDir) {
                                            browserViewContainer.lastPath = networkPopupWindow.currentBrowserPath;
                                            browserViewContainer.pendingPath = fileUrl.toString();
                                            pathFadeAnimation.start();
                                        } else {
                                            let urlString = fileUrl.toString();
                                            let parsedPath = urlString.startsWith("file:///") ? urlString.substring(7) : urlString.replace("file://", "");
                                            vpnImporter.command = ["bash", "-c", "nmcli connection import file '" + parsedPath + "' || echo 'QS_IMPORT_FAILED' >&2"];
                                            vpnImporter.running = true;
                                            networkPopupWindow.showFileBrowser = false;
                                        }
                                    }
                                }
                            }

                            SequentialAnimation {
                                id: pathFadeAnimation
                                ParallelAnimation {
                                    PropertyAnimation { target: browserViewContainer; property: "opacity"; from: 1.0; to: 0.0; duration: 110 }
                                    PropertyAnimation { target: browserViewContainer; property: "x"; to: (browserViewContainer.pendingPath.length > browserViewContainer.lastPath.length) ? -30 : 30; duration: 110 }
                                }
                                ScriptAction { script: { networkPopupWindow.currentBrowserPath = browserViewContainer.pendingPath; } }
                                PropertyAction { target: browserViewContainer; property: "x"; value: (browserViewContainer.pendingPath.length > browserViewContainer.lastPath.length) ? 30 : -30 }
                                ParallelAnimation {
                                    PropertyAnimation { target: browserViewContainer; property: "opacity"; from: 0.0; to: 1.0; duration: 130 }
                                    PropertyAnimation { target: browserViewContainer; property: "x"; to: 0; duration: 130 }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // --- Backend Drivers ---
    Process {
        id: vpnListPopulator
        command: ["nmcli", "-g", "TYPE,NAME,STATE", "connection", "show"]
        running: false
        
        stdout: StdioCollector {
            onTextChanged: {
                let cleanText = text.trim();
                if (!cleanText) { vpnListModel.clear(); networkPopupWindow.activeVpnName = ""; return; }
                let lines = cleanText.split("\n");
                let incomingProfiles = [];
                let currentActive = "";

                for (let i = 0; i < lines.length; i++) {
                    let parts = lines[i].trim().split(":");
                    if (parts.length >= 2) {
                        let type = parts[0], name = parts[1], state = parts[2] || "";
                        
                        // EXPANDED FILTER: Captures standard wireguard, generic VPNs, tun links, and raw virtual devices
                        if (type === "wireguard" || type === "vpn" || type === "tun" || type === "overlay" || type === "connection") {
                            if (state.indexOf("activated") !== -1) currentActive = name;
                            if (incomingProfiles.indexOf(name) === -1) incomingProfiles.push(name);
                        }
                    }
                }

                networkPopupWindow.activeVpnName = currentActive;
                for (let m = vpnListModel.count - 1; m >= 0; m--) {
                    if (incomingProfiles.indexOf(vpnListModel.get(m).profileName) === -1) vpnListModel.remove(m);
                }
                for (let p = 0; p < incomingProfiles.length; p++) {
                    let pName = incomingProfiles[p], found = false;
                    for (let m = 0; m < vpnListModel.count; m++) { if (vpnListModel.get(m).profileName === pName) { found = true; break; } }
                    if (!found) vpnListModel.append({ "profileName": pName });
                }
            }
        }
    }

    Process { id: vpnStateExecutor; running: false; onExited: vpnListPopulator.running = true }
    Process { id: vpnImporter; running: false; onExited: vpnListPopulator.running = true }

    function toggleProfileState(profileName, itemChecked) {
        vpnStateExecutor.command = itemChecked 
            ? ["nmcli", "connection", "up", "id", profileName]
            : ["nmcli", "connection", "down", "id", profileName];
        vpnStateExecutor.running = true;
    }

    function deleteProfile(profileName) {
        vpnStateExecutor.command = ["nmcli", "connection", "delete", "id", profileName];
        vpnStateExecutor.running = true;
    }

    onVisibleChanged: {
        if (visible) {
            outsideDismiss.forceActiveFocus();
            vpnListPopulator.running = true;
            networkPopupWindow.animateActive = true;
        } else {
            networkPopupWindow.animateActive = false;
        }
    }
}
