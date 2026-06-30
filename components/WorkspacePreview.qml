import QtQuick
import QtQuick.Layouts
import Quickshell
import QtQuick.Controls
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io

Item {
    id: previewRoot

    signal closeRequested()

    property int targetWorkspace: -1 
    property bool active: false
    
    property int stagedWorkspace: -1
    property var liveClientJson: []

    property int currentActiveWorkspace: -1
    property int workingWorkspace: -1

    property bool isHovered: globalTrackingArea.containsMouse || contentHoverHandler.hovered

    property var rootWindow: Quickshell.window

    // --- SYSTEM THEME MATRIX ---
    property color colorBackground: shellConfig.colorBackground
    property color colorBorder: shellConfig.colorBorder
    property color colorAccent: shellConfig.colorAccent
    property string shellFont: shellConfig.shellFont
    property real radiusValue: shellConfig.radiusValue

    // Dynamically expand root width to tightly match the workspace stream aspect bounds plus side paddings
    property real maxCardWidth: viewportFrame.width + 74
    property real maxCardHeight: viewportFrame.calculatedBounds.isVertical ? 500 : 270

    implicitWidth: Math.round(maxCardWidth)
    implicitHeight: viewportFrame.calculatedBounds.isVertical ? 500 : 270

    width: implicitWidth
    height: implicitHeight
    
    Behavior on width { 
        id: widthMorphBehavior
        NumberAnimation { duration: 220; easing.type: Easing.OutCubic } 
    }
    Behavior on height { 
        id: heightMorphBehavior
        NumberAnimation { duration: 220; easing.type: Easing.OutCubic } 
    }

    opacity: 1.0
    visible: true
    clip: false

    onTargetWorkspaceChanged: {
        if (targetWorkspace !== -1) {
            debounceTimer.restart();
        } else {
            debounceTimer.stop();
            previewRoot.active = false;
        }
    }

    Timer {
        id: debounceTimer
        interval: 50
        running: false
        repeat: false
        onTriggered: {
            if (previewRoot.targetWorkspace !== -1) {
                Hyprland.refreshToplevels();
                Hyprland.refreshWorkspaces();
                
                previewRoot.workingWorkspace = previewRoot.targetWorkspace;
                clientQueryProcess.running = true;
                previewRoot.active = true;
            }
        }
    }

    Timer {
        id: jsonRefreshTimer
        interval: 100
        running: false
        onTriggered: clientQueryProcess.running = true
    }

    Connections {
        target: Hyprland
        ignoreUnknownSignals: true
        function onRawEvent(event) { 
            if (previewRoot.active) jsonRefreshTimer.restart();
        }
    }

    Process {
        id: clientQueryProcess
        command: ["hyprctl", "clients", "-j"]
        running: false
        stdout: StdioCollector {
            onTextChanged: {
                let cleanText = text.trim();
                if (!cleanText || cleanText === "[]") return;
                try { previewRoot.liveClientJson = JSON.parse(cleanText);
                } catch(e) {}
            }
        }
    }

    function getCleanIconName(className) {
        if (!className) return "application-x-executable";
        let lowerClass = className.toLowerCase().trim();
        if (lowerClass.includes("chrome")) return "google-chrome";
        if (lowerClass.includes("kitty")) return "kitty";
        if (lowerClass.includes("terminal")) return "utilities-terminal";
        if (lowerClass.includes("codium")) return "vscodium";
        if (lowerClass.includes("code")) return "vscode";
        if (lowerClass.includes("signal")) return "signal-desktop";
        return lowerClass;
    }

    Item {
        id: animatedGroup
        anchors.fill: parent

        opacity: previewRoot.active ? 1.0 : 0.0
        x: previewRoot.active ? 0 : -50
        
        visible: previewRoot.active || exitXAnimation.running || opacity > 0.01

        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        
        Behavior on x { 
            id: exitXAnimation
            NumberAnimation { duration: 250; easing.type: Easing.OutCubic } 
        }
        
        Rectangle {
            id: cardMainBody
            anchors.fill: parent
            color: previewRoot.colorBackground
            z: 2
            radius: previewRoot.radiusValue
        }

        // --- TV ANTENNA ICON ---
        Text {
            id: antennaIcon
            text: "network_ping"
            font {
                family: "Material Symbols Outlined"
                pixelSize: 80
            }
            color: previewRoot.colorBackground
            //style: Text.Outline
            styleColor: colorBackground
            z: 1
            anchors.bottom: cardMainBody.top
            anchors.horizontalCenter: cardMainBody.horizontalCenter
            anchors.bottomMargin: -28
        }

        Item {
            id: borderClippingMask
            anchors.fill: parent
            clip: false 
            z: 4

            Rectangle {
                id: borderFrame
                anchors.fill: parent
                anchors.leftMargin: -2
                anchors.topMargin: 0
                anchors.rightMargin: 0
                anchors.bottomMargin: 0
                color: "transparent"
                border.color: previewRoot.colorBorder
                border.width: 0
                radius: previewRoot.radiusValue
            }
        }

        MouseArea { 
            id: globalTrackingArea
            anchors.fill: parent 
            hoverEnabled: true 
            acceptedButtons: Qt.LeftButton 
            onClicked: {
                Hyprland.dispatch(`hl.dsp.focus({ workspace = "${previewRoot.workingWorkspace}" })`);
                previewRoot.closeRequested();
            }
            z: 4
        }

        Item {
            id: layoutContentWrapper
            width: Math.round(previewRoot.maxCardWidth)
            height: Math.round(previewRoot.maxCardHeight)
            x: Math.round((parent.width - width) / 2)
            y: Math.round((parent.height - height) / 2)
            opacity: previewRoot.active ? 1.0 : 0.0 
            z: 5

            Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.InOutQuad } }

            HoverHandler {
                id: contentHoverHandler
            }

            Item {
                anchors.fill: parent
                anchors.margins: 14

                // --- TV KNOBS (INSIDE WINDOW, LEFT SIDE) ---
                Column {
                    id: tvKnobsColumn
                    anchors.left: parent.left
                    anchors.leftMargin: 4
                    anchors.verticalCenter: parent.verticalCenter
                    width: 24
                    spacing: 16

                    Text {
                        text: "clock_loader_10"
                        font {
                            family: "Material Symbols Outlined"
                            pixelSize: 30
                        }
                        color: Qt.rgba(1, 1, 1, 0.4)
                        style: Text.Outline
                        styleColor: Qt.rgba(0, 0, 0, 0.35)
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 30
                        height: 30
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter

                        // Direct, zero-overhead horizontal mirror
                        rotation: -45
                    }

                    Text {
                        text: "clock_loader_10"
                        font {
                            family: "Material Symbols Outlined"
                            pixelSize: 30
                        }
                        color: Qt.rgba(1, 1, 1, 0.4)
                        style: Text.Outline
                        styleColor: Qt.rgba(0, 0, 0, 0.35)
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 30
                        height: 30
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter

                        // Direct, zero-overhead horizontal mirror
                        rotation: 45
                    }

                    Text {
                        text: "density_small"
                        font {
                            family: "Material Symbols Outlined"
                            pixelSize: 30
                        }
                        color: Qt.rgba(1, 1, 1, 0.4)
                        style: Text.Outline
                        styleColor: Qt.rgba(0, 0, 0, 0.35)
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }

                RowLayout {
                    id: headerRow
                    width: parent.width - tvKnobsColumn.width - 16
                    height: 20
                    spacing: 16
                    anchors.top: parent.top
                    anchors.left: tvKnobsColumn.right
                    anchors.leftMargin: 0

                    // Dummy item to push content from the left
                    Item { Layout.fillWidth: true }

                    // Centered Content Wrapper
                    Row {
                        id: centeredContent
                        spacing: 16
                        Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter

                        Text {
                            id: titleLabel
                            text: previewRoot.workingWorkspace !== -1 ? "Workspace " + previewRoot.workingWorkspace : ""
                            font.family: previewRoot.shellFont
                            font.pixelSize: 13
                            font.bold: true
                            color: "#ffffff"
                            anchors.verticalCenter: parent.verticalCenter
                            style: Text.Outline
                            styleColor: Qt.rgba(0, 0, 0, 0.35)
                        }

                        RowLayout {
                            id: iconContainerRow
                            height: parent.height
                            spacing: 8
                            anchors.verticalCenter: parent.verticalCenter
                            
                            Repeater {
                                model: viewportFrame.workspaceWindows
                                delegate: Image {
                                    visible: (modelData.class || "") !== "" && modelData.mapped
                                    source: Quickshell.iconPath(getCleanIconName(modelData.class))
                                    Layout.preferredWidth: 16
                                    Layout.preferredHeight: 16
                                    Layout.alignment: Qt.AlignVCenter
                                    fillMode: Image.PreserveAspectFit
                                }
                            }
                        }
                    }

                    // Dummy item to push content from the right
                    Item { Layout.fillWidth: true }
                }

                Rectangle {
                    id: headerDivider
                    width: parent.width - tvKnobsColumn.width - 16
                    height: 1
                    color: previewRoot.colorBorder
                    anchors.top: headerRow.bottom
                    anchors.topMargin: 4
                    anchors.left: tvKnobsColumn.right
                    anchors.leftMargin: 16
                }

                Rectangle {
                    id: viewportFrame
                    anchors.left: tvKnobsColumn.right
                    anchors.leftMargin: 16
                    anchors.top: headerDivider.bottom
                    anchors.topMargin: 8
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 2
                    color: "transparent" 
                    radius: 4
                    clip: true

                    property var workspaceWindows: previewRoot.liveClientJson.filter(w => w.workspace.id === previewRoot.workingWorkspace)
                    property bool isTargetActiveWorkspace: !!(Hyprland.activeWorkspace && (previewRoot.workingWorkspace === Hyprland.activeWorkspace.id))

                    property var calculatedBounds: {
                        if (previewRoot.workingWorkspace === -1 || !workspaceWindows || workspaceWindows.length === 0) {
                            let mX = 0, mY = 0, mWidth = 1920, mHeight = 1080;
                            let wsObj = Hyprland.workspaces.values.find(w => w.id === previewRoot.workingWorkspace);
                            let targetMonitor = wsObj ? wsObj.monitor : Hyprland.activeMonitor;
                            if (targetMonitor) {
                                let scale = targetMonitor.scale > 0 ? targetMonitor.scale : 1.0;
                                mWidth = Math.round(targetMonitor.width / scale);
                                mHeight = Math.round(targetMonitor.height / scale);
                                mX = targetMonitor.x;
                                mY = targetMonitor.y;
                                let barThickness = 44;
                                mX += barThickness; 
                                mWidth -= barThickness;
                            }
                            return { "w": mWidth, "h": mHeight, "isVertical": mHeight > mWidth, "originX": mX, "originY": mY };
                        }

                        let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity;
                        for (let i = 0; i < workspaceWindows.length; i++) {
                            let win = workspaceWindows[i];
                            if (!win.at || !win.size) continue;
                            if (win.at[0] < minX) minX = win.at[0];
                            if (win.at[1] < minY) minY = win.at[1];
                            if ((win.at[0] + win.size[0]) > maxX) maxX = win.at[0] + win.size[0];
                            if ((win.at[1] + win.size[1]) > maxY) maxY = win.at[1] + win.size[1];
                        }

                        let spanX = maxX - minX;
                        let spanY = maxY - minY;
                        let verticalDetected = spanY > spanX;
                        
                        let normW = verticalDetected ? 1080 : 1920;
                        let normH = verticalDetected ? 1920 : 1080;
                        
                        if (spanX > 0 && Math.abs(spanX - normW) > 100) normW = spanX;
                        if (spanY > 0 && Math.abs(spanY - normH) > 100) normH = spanY;
                        return { "w": normW, "h": normH, "isVertical": verticalDetected, "originX": minX, "originY": minY };
                    }

                    width: Math.round(height * (calculatedBounds.w / calculatedBounds.h))
                    property real scaleX: width / calculatedBounds.w
                    property real scaleY: height / calculatedBounds.h

                    Repeater {
                        model: viewportFrame.workspaceWindows
                        delegate: Rectangle {
                            id: windowDelegate
                        
                            x: Math.round((modelData.at[0] - viewportFrame.calculatedBounds.originX) * viewportFrame.scaleX)
                            y: Math.round((modelData.at[1] - viewportFrame.calculatedBounds.originY) * viewportFrame.scaleY)
                            width: Math.max(4, Math.round(modelData.size[0] * viewportFrame.scaleX))
                            height: Math.max(4, Math.round(modelData.size[1] * viewportFrame.scaleY))
                            visible: modelData.mapped
                            
                            color: viewportFrame.isTargetActiveWorkspace ? Qt.rgba(previewRoot.colorAccent.r, previewRoot.colorAccent.g, previewRoot.colorAccent.b, 0.15) : Qt.rgba(0, 0, 0, 0.6)
                            border.color: viewportFrame.isTargetActiveWorkspace ? previewRoot.colorAccent : previewRoot.colorBorder
                            border.width: 0
                            radius: 2
                            clip: true

                            property var wlToplevel: {
                                if (!modelData || !modelData.address) return null;
                                let tracker = clientQueryProcess.running;
                                let targetAddr = modelData.address.trim().toLowerCase();

                                let match = Hyprland.toplevels.values.find(t => {
                                    if (!t.lastIpcObject || !t.lastIpcObject.address) return false;
                                    return t.lastIpcObject.address.trim().toLowerCase() === targetAddr;
                                });
                                if (match && match.wayland) return match.wayland;
                                
                                if (Hyprland.activeWorkspace) {
                                    let localMatch = Hyprland.activeWorkspace.toplevels.values.find(t => {
                                        if (!t.lastIpcObject || !t.lastIpcObject.address) return false;
                                        return t.lastIpcObject.address.trim().toLowerCase() === targetAddr;
                                    });
                                    if (localMatch && localMatch.wayland) return localMatch.wayland;
                                }
                                return null;
                            }

                            Loader {
                                anchors.fill: parent
                                active: windowDelegate.wlToplevel !== null && !viewportFrame.isTargetActiveWorkspace
                                asynchronous: true 
                                
                                opacity: status === Loader.Ready ? 1.0 : 0.0
                                Behavior on opacity { NumberAnimation { duration: 150 } }

                                sourceComponent: Component {
                                    ScreencopyView {
                                        captureSource: windowDelegate.wlToplevel
                                        live: true
                                        paintCursor: false
                                    }
                                }
                            }

                            Rectangle {
                                anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
                                height: Math.min(14, parent.height * 0.25)
                                color: viewportFrame.isTargetActiveWorkspace ? previewRoot.colorAccent : "#cc11111b"
                                visible: parent.height > 20 && parent.width > 35
                                z: 10

                                Text {
                                    text: (modelData.title && modelData.title.trim() !== "" && modelData.title !== "~") ? modelData.title : (modelData.class || "")
                                    font.family: previewRoot.shellFont
                                    font.pixelSize: 8; font.bold: true 
                                    color: viewportFrame.isTargetActiveWorkspace ? previewRoot.colorBackground : "#ffffff"
                                    anchors.centerIn: parent
                                    width: parent.width - 4; elide: Text.ElideRight; horizontalAlignment: Text.AlignHCenter
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
