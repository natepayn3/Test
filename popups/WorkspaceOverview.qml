import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import "../configs"

PanelWindow {
    id: overviewWindow

    // --- ACCELERATED LAYER CONFIGURATION ---
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-workspace-overview"
    WlrLayershell.keyboardFocus: WlrLayershell.OnDemand
    WlrLayershell.exclusionMode: WlrLayershell.Ignore

    color: fontCfg.trackBackground

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    // FIXED: Bind directly to the global shell root property to prevent sync desaturation
    property bool isOverviewActive: shellRoot.isOverviewActive
    visible: isOverviewActive

    // --- NATIVE IPC ROUTING MATRIX ---
    IpcHandler {
        target: "overview"
        
        // FIXED: Mutate the global state wrapper handler path
        function toggle(): void {
            shellRoot.isOverviewActive = !shellRoot.isOverviewActive;
        }
    }

    // --- INTERNAL STATES & PROCESS FORK ENGINE ---
    property var liveClientJson: []

    onVisibleChanged: {
        if (visible) {
            overviewWindow.WlrLayershell.keyboardFocus = WlrLayershell.OnDemand;
            overviewContent.focus = true;
            clientQueryProcess.running = true; 
        } else {
            overviewWindow.WlrLayershell.keyboardFocus = WlrLayershell.None;
            clientQueryProcess.running = false;
        }
    }

    readonly property var activeWorkspaceList: {
        let ids = [1];
        for (let i = 0; i < Hyprland.workspaces.values.length; i++) {
            let ws = Hyprland.workspaces.values[i];
            if (ws.id > 0 && !ids.includes(ws.id)) {
                ids.push(ws.id);
            }
        }
        return ids.sort((a, b) => a - b);
    }
    
    readonly property int activeWorkspace: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1

    property color colorBackground: shellConfig.colorBackground
    property color colorBorder: shellConfig.colorBorder
    property color colorAccent: shellConfig.colorAccent
    property string shellFont: shellConfig.shellFont
    property real radiusValue: shellConfig.radiusValue

    FontConfig { id: fontCfg }

    Process {
        id: clientQueryProcess
        command: ["hyprctl", "clients", "-j"]
        running: false
        stdout: StdioCollector {
            onTextChanged: {
                let cleanText = text.trim();
                if (!cleanText || cleanText === "[]") return;
                try { 
                    overviewWindow.liveClientJson = JSON.parse(cleanText);
                } catch(e) {}
            }
        }
    }

    Connections {
        target: Hyprland
        ignoreUnknownSignals: true
        function onRawEvent(event) { 
             if (overviewWindow.visible) clientQueryProcess.running = true;
        }
    }

    Item {
        id: overviewContent
        anchors.fill: parent
        focus: true

        // FIXED: Clear structural state globally on escape key intercept
        Keys.onPressed: (event) => {
            if (event.key === Qt.Key_Escape) {
                shellRoot.isOverviewActive = false;
                event.accepted = true;
            }
        }

        // FIXED: Clear structural state globally on background layer tap
        TapHandler {
            onTapped: { shellRoot.isOverviewActive = false; }
        }

        // --- GRID MATRIX ---
        Grid {
            id: overviewGrid
            anchors.centerIn: parent
            columns: 4
            spacing: 28

            Repeater {
                model: overviewWindow.activeWorkspaceList

                delegate: Rectangle {
                    id: workspaceTile
                    property int currentWsId: modelData
                    property bool isTargetActive: overviewWindow.activeWorkspace === currentWsId

                    // --- PORTED DYNAMIC VIEWPORT DIMENSION ENGINE ---
                    width: Math.round(viewportFrame.width + 28)
                    height: 260
                    radius: 12
                    
                    color: overviewWindow.colorBackground
                    border.color: isTargetActive ? fontCfg.textPrimary : fontCfg.borderMuted
                    border.width: isTargetActive ? 2 : 1

                    scale: tileMouseArea.containsMouse ? 1.02 : 1.0
                    Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                    Behavior on border.color { ColorAnimation { duration: 180 } }

                    Text {
                        id: titleLabel
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.margins: 14
                        text: "Workspace " + currentWsId
                        font.family: fontCfg.mainFont
                        font.pixelSize: 13
                        font.bold: true
                        color: workspaceTile.isTargetActive ? fontCfg.textPrimary : fontCfg.textMuted
                        z: 3
                    }

                    Item {
                        id: viewportFrame
                        anchors.top: titleLabel.bottom
                        anchors.bottom: parent.bottom
                        anchors.margins: 14
                        anchors.topMargin: 8
                        anchors.horizontalCenter: parent.horizontalCenter
                        clip: true
                        z: 2

                        property var workspaceWindows: overviewWindow.liveClientJson.filter(w => w.workspace.id === workspaceTile.currentWsId)

                        property var calculatedBounds: {
                            if (!workspaceWindows || workspaceWindows.length === 0) {
                                let mWidth = 1920, mHeight = 1080, mX = 0, mY = 0;
                                let wsObj = Hyprland.workspaces.values.find(w => w.id === workspaceTile.currentWsId);
                                let targetMonitor = wsObj ? wsObj.monitor : Hyprland.activeMonitor;
                                if (targetMonitor) {
                                    let scale = targetMonitor.scale > 0 ? targetMonitor.scale : 1.0;
                                    mWidth = Math.round(targetMonitor.width / scale);
                                    mHeight = Math.round(targetMonitor.height / scale);
                                    mX = targetMonitor.x;
                                    mY = targetMonitor.y;
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

                        Rectangle {
                            anchors.fill: parent
                            color: fontCfg.overlayBackground
                            radius: 4
                            z: 1
                        }

                        Repeater {
                            model: viewportFrame.workspaceWindows
                            delegate: Rectangle {
                                id: windowDelegate
                            
                                x: Math.round((modelData.at[0] - viewportFrame.calculatedBounds.originX) * viewportFrame.scaleX)
                                y: Math.round((modelData.at[1] - viewportFrame.calculatedBounds.originY) * viewportFrame.scaleY)
                                width: Math.max(4, Math.round(modelData.size[0] * viewportFrame.scaleX))
                                height: Math.max(4, Math.round(modelData.size[1] * viewportFrame.scaleY))
                                visible: modelData.mapped
                                z: 2
                                
                                color: workspaceTile.isTargetActive ? 
                                    Qt.rgba(fontCfg.textPrimary.r, fontCfg.textPrimary.g, fontCfg.textPrimary.b, 0.15) : fontCfg.overlayBackground
                                border.color: workspaceTile.isTargetActive ? fontCfg.textPrimary : fontCfg.borderMuted
                                border.width: 1
                                radius: 4

                                property var wlToplevel: {
                                    if (!modelData || !modelData.address) return null;
                                    let targetAddr = modelData.address.trim().toLowerCase();
                                    let match = Hyprland.toplevels.values.find(t => {
                                        if (!t.lastIpcObject || !t.lastIpcObject.address) return false;
                                        return t.lastIpcObject.address.trim().toLowerCase() === targetAddr;
                                    });
                                    if (match && match.wayland) return match.wayland;
                                    return null;
                                }

                                Loader {
                                    anchors.fill: parent
                                    anchors.margins: 1
                                    active: windowDelegate.wlToplevel !== null
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
                                    anchors.top: parent.top
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    height: Math.min(16, parent.height * 0.3)
                                    color: workspaceTile.isTargetActive ? fontCfg.textPrimary : "#cc11111b"
                                    visible: parent.height > 24 && parent.width > 40
                                    radius: 2

                                    Text {
                                        text: (modelData.class || "")
                                        font.family: fontCfg.mainFont
                                        font.pixelSize: 8
                                        font.bold: true 
                                        color: workspaceTile.isTargetActive ? "#000000" : fontCfg.textPrimary
                                        anchors.centerIn: parent
                                        width: parent.width - 4
                                        elide: Text.ElideRight
                                        horizontalAlignment: Text.AlignHCenter
                                    }
                                }
                            }
                        }
                    }

                    MouseArea {
                        id: tileMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        
                        // FIXED: Drop overlay cleanly globally when target workspace card is clicked
                        onClicked: {
                            Hyprland.dispatch(`hl.dsp.focus({ workspace = "${currentWsId}" })`);
                            shellRoot.isOverviewActive = false;
                        }
                    }
                }
            }
        }
    }
}
