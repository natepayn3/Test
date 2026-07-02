import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../components"
import "../configs"
import "../popups"

PanelWindow {
    id: sideDockWindow

    WlrLayershell.namespace: "quickshell-launcher"
    WlrLayershell.keyboardFocus: WlrLayershell.None

    // Direct clickthrough mask binding via native QsWindow property
    mask: Region {
        Region { item: hotspotTrigger }
        Region { item: dockHitbox.isPinned ? visualColumnContainer : null }
    }

    // --- ENGINES & CONFIG LINKAGES ---
    FontConfig { id: fontCfg }
    ModuleConfig { id: config } // Added configuration module hook

    // --- SYSTEM THEME MATRIX & PREVIEW LAYER COMPATIBILITY ---
    property color themeText: "#ffffff"
    property color themeAccent: Qt.rgba(0.4, 0.4, 0.4, 0.28)
    property color hoverBorder: config.hoverBorder // Strictly using config for hoverBorder
    
    readonly property string barPosition: "left"
    property color colorBackground: Qt.rgba(0.06, 0.06, 0.1, 0.95)
    property color colorBorder: Qt.rgba(1, 1, 1, 0.1)
   
    property color colorAccent: Qt.rgba(0.6, 0.45, 0.9, 1.0)
    property string shellFont: fontCfg.mainFont // Restored original tracking

    anchors {
        left: true
    }
    
    implicitWidth: 72
    implicitHeight: visualColumnContainer.height + 32
    color: "transparent"
    exclusiveZone: 0

    // --- INTERNAL WORKSPACE MODEL HANDLING ---
    property int activeWorkspace: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1
    property var activeWorkspaceList: [1]
    property var occupiedMap: ({})
    property int maxWorkspaceId: 1

    property bool isSpecialOccupied: false
    property bool isSpecialActive: false

    function rebuildWorkspaceData() {
        let occupied = {};
        let specialHasWindows = false;
        let ids = [];

        for (let i = 0; i < Hyprland.workspaces.values.length; i++) {
            let ws = Hyprland.workspaces.values[i];
            if (ws.id > 0) {
                occupied[ws.id] = true;
                ids.push(ws.id);
            } else if (ws.name && (ws.name.startsWith("special") || ws.id < 0)) {
                specialHasWindows = true;
            }
        }

        sideDockWindow.occupiedMap = occupied;
        sideDockWindow.isSpecialOccupied = specialHasWindows;

        if (!ids.includes(1)) ids.push(1);
        if (!ids.includes(sideDockWindow.activeWorkspace)) ids.push(sideDockWindow.activeWorkspace);

        let maxId = Math.max(...ids, 0);
        sideDockWindow.maxWorkspaceId = maxId;
        let cleanIds = [];
        for (let i = 1; i <= maxId; i++) {
            cleanIds.push(i);
        }
        
        sideDockWindow.activeWorkspaceList = cleanIds;
    }

    Connections {
        target: Hyprland.workspaces
        function onValuesChanged() { sideDockWindow.rebuildWorkspaceData(); }
    }

    Connections {
        target: Hyprland
        function onFocusedWorkspaceChanged() { sideDockWindow.rebuildWorkspaceData(); }
        function onRawEvent(event) {
            if (event.name === "activespecial" || event.name === "activespecialv2") {
                const wsName = event.data.split(',')[0];
                sideDockWindow.isSpecialActive = (wsName !== "");
                sideDockWindow.rebuildWorkspaceData();
            }
            if (event.name === "destroyworkspace") {
                sideDockWindow.rebuildWorkspaceData();
            }
        }
    }

    Component.onCompleted: sideDockWindow.rebuildWorkspaceData()

    Item {
        id: masterContainer
        anchors.fill: parent

        MouseArea {
            id: hotspotTrigger
            width: 14
            height: parent.height - 16
          
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            hoverEnabled: true
        }

        MouseArea {
            id: dockHitbox
            anchors.fill: parent
            hoverEnabled: true

            property int activeHoverIndex: -1
            property bool stableHover: hotspotTrigger.containsMouse || dockHitbox.containsMouse || previewCard.isHovered
            property bool isPinned: false

            onStableHoverChanged: {
                if (stableHover) {
                    dismissTimer.stop();
                    isPinned = true;
                } else {
                    dismissTimer.start();
                }
            }

            Rectangle {
                id: visualColumnContainer
                width: 58
                height: visualColumn.implicitHeight + 20
                radius: 12 // Restored hardcoded property
     
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: dockHitbox.isPinned ? 5 : -75

                color: Qt.rgba(0, 0, 0, 0.01)

                Behavior on anchors.leftMargin {
                    NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                }

                Column {
                    id: visualColumn
                    spacing: 12
                    anchors.centerIn: parent

                    // --- STANDARD NODES REPEATER ---
                    Repeater {
                        model: sideDockWindow.activeWorkspaceList
                        
                        delegate: Item {
                            property int wsId: modelData
                            property bool isActive: sideDockWindow.activeWorkspace === wsId && !sideDockWindow.isSpecialActive
                            property bool isOccupied: sideDockWindow.occupiedMap[wsId] === true

                            width: 54
                            height: 54

                            Rectangle {
                                width: parent.isActive ? 54 : 44
                                height: parent.isActive ? 54 : 44
                                radius: 10
                                anchors.centerIn: parent
                                
                                color: dockHitbox.activeHoverIndex === index ? sideDockWindow.themeAccent : "transparent"
                                border.color: dockHitbox.activeHoverIndex === index ? sideDockWindow.hoverBorder : "transparent"
                                border.width: 1
                                
                                Behavior on width { NumberAnimation { duration: 140; easing.type: Easing.OutQuad } }
                                Behavior on height { NumberAnimation { duration: 140; easing.type: Easing.OutQuad } }
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }

                            Text {
                                anchors.centerIn: parent
                                font.family: fontCfg.iconFont // Restored local FontConfig tracking
                                font.pixelSize: parent.isActive ? 28 : 22
                                style: Text.Outline
                                styleColor: Qt.rgba(0, 0, 0, 0.35)
                           
                                // Dynamic opacity matching the workspace state
                                color: {
                                    if (!dockHitbox.isPinned) return "transparent";
                                    
                                    let baseColor = sideDockWindow.themeText;
                                    let alpha = 0.25; // Default: Empty workspace
                                    
                                    if (parent.isActive) {
                                        alpha = 1.0;
                                    } else if (parent.isOccupied) {
                                        alpha = 0.65;
                                    }
                                    
                                    return Qt.rgba(baseColor.r, baseColor.g, baseColor.b, alpha);
                                }
                                
                                text: "counter_" + (wsId % 10)
                               
                                Component.onCompleted: fontCfg.applySmoothing(this)
                                Behavior on font.pixelSize { NumberAnimation { duration: 140 } }
                                Behavior on color { ColorAnimation { duration: 180 } }
                            }
                        }
                    }

                    // --- ADD WORKSPACE BUTTON ---
                    Item {
                        width: 54
                        height: 54

                        Rectangle {
                            width: 44
                            height: 44
                            radius: 10
                            anchors.centerIn: parent
                            color: dockHitbox.activeHoverIndex === sideDockWindow.activeWorkspaceList.length ? sideDockWindow.themeAccent : "transparent"
                            border.color: dockHitbox.activeHoverIndex === sideDockWindow.activeWorkspaceList.length ? sideDockWindow.hoverBorder : "transparent"
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "add"
                            font.family: fontCfg.iconFont // Restored local FontConfig tracking
                            font.pixelSize: 22
                            style: Text.Outline
                            styleColor: Qt.rgba(0, 0, 0, 0.35)
                            color: dockHitbox.isPinned ? Qt.rgba(sideDockWindow.themeText.r, sideDockWindow.themeText.g, sideDockWindow.themeText.b, 0.9) : "transparent"
                            
                            Component.onCompleted: fontCfg.applySmoothing(this)
                            Behavior on color { ColorAnimation { duration: 180 } }
                        }
                    }

                    // --- SPECIAL WORKSPACE INDICATOR ---
                    Item {
                        visible: sideDockWindow.isSpecialOccupied
                        width: 54
                        height: 54

                        Rectangle {
                            width: sideDockWindow.isSpecialActive ? 54 : 44
                            height: sideDockWindow.isSpecialActive ? 54 : 44
                            radius: 10
                            anchors.centerIn: parent
                            color: dockHitbox.activeHoverIndex === (sideDockWindow.activeWorkspaceList.length + 1) ? sideDockWindow.themeAccent : "transparent"
                            border.color: dockHitbox.activeHoverIndex === (sideDockWindow.activeWorkspaceList.length + 1) ? sideDockWindow.hoverBorder : "transparent"
                            border.width: 1
                            
                            Behavior on width { NumberAnimation { duration: 140; easing.type: Easing.OutQuad } }
                            Behavior on height { NumberAnimation { duration: 140; easing.type: Easing.OutQuad } }
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }

                        Text {
                            anchors.centerIn: parent
                            font.family: fontCfg.iconFont // Restored local FontConfig tracking
                            font.pixelSize: sideDockWindow.isSpecialActive ? 28 : 22
                            style: Text.Outline
                            styleColor: Qt.rgba(0, 0, 0, 0.35)
                            color: dockHitbox.isPinned ? Qt.rgba(sideDockWindow.themeText.r, sideDockWindow.themeText.g, sideDockWindow.themeText.b, 0.9) : "transparent"
                            text: sideDockWindow.isSpecialActive ? "family_star" : "kid_star"
                            
                            Component.onCompleted: fontCfg.applySmoothing(this)
                            Behavior on font.pixelSize { NumberAnimation { duration: 140 } }
                            Behavior on color { ColorAnimation { duration: 180 } }
                        }
                    }
                }

                // --- CONTIGUOUS MOUSE GRID TARGET OVERLAY ---
                MouseArea {
                    anchors.fill: visualColumn
                    hoverEnabled: true
                    cursorShape: dockHitbox.activeHoverIndex !== -1 ? Qt.PointingHandCursor : Qt.ArrowCursor

                    onPositionChanged: (mouse) => {
                        let totalCellHeight = 66;
                        let calculatedIndex = Math.floor(mouse.y / totalCellHeight);
                        let localY = mouse.y % totalCellHeight;
                        let totalCount = sideDockWindow.activeWorkspaceList.length + (sideDockWindow.isSpecialOccupied ? 2 : 1);
                        if (calculatedIndex >= 0 && calculatedIndex < totalCount && localY <= 54 && mouse.y >= 0) {
                            dockHitbox.activeHoverIndex = calculatedIndex;
                            if (calculatedIndex < sideDockWindow.activeWorkspaceList.length) {
                                previewWindow.targetWorkspace = sideDockWindow.activeWorkspaceList[calculatedIndex];
                            } else {
                                previewWindow.targetWorkspace = -1;
                            }
                        } else {
                            dockHitbox.activeHoverIndex = -1;
                            previewWindow.targetWorkspace = -1;
                        }
                    }

                    onExited: {
                        dockHitbox.activeHoverIndex = -1;
                        previewWindow.targetWorkspace = -1;
                    }

                    onClicked: (mouse) => {
                        if (dockHitbox.activeHoverIndex >= 0 && dockHitbox.activeHoverIndex < sideDockWindow.activeWorkspaceList.length) {
                            let targetWs = sideDockWindow.activeWorkspaceList[dockHitbox.activeHoverIndex];
                            Hyprland.dispatch(`hl.dsp.focus({ workspace = "${targetWs}" })`);
                        } else if (dockHitbox.activeHoverIndex === sideDockWindow.activeWorkspaceList.length) {
                            let nextWs = sideDockWindow.maxWorkspaceId + 1;
                            Hyprland.dispatch(`hl.dsp.focus({ workspace = "${nextWs}" })`);
                        } else if (dockHitbox.activeHoverIndex === (sideDockWindow.activeWorkspaceList.length + 1) && sideDockWindow.isSpecialOccupied) {
                            Hyprland.dispatch(`hl.dsp.workspace.toggle_special("magic")`);
                        }
                    }
                }
            }
        }
    }

    Timer {
        id: dismissTimer
        interval: 500
        running: false
        repeat: false
        onTriggered: {
            dockHitbox.isPinned = false;
            dockHitbox.activeHoverIndex = -1;
            previewWindow.targetWorkspace = -1;
        }
    }

    // --- INTEGRATED COMPANION PREVIEW LAYER ---
    PanelWindow {
        id: previewWindow
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-workspace-preview"
        WlrLayershell.keyboardFocus: WlrLayershell.None
        WlrLayershell.exclusionMode: WlrLayershell.Ignore
        
        anchors {
            left: true
            top: true
            bottom: true
        }
        
        implicitWidth: previewCard.active ? (68 + previewCard.width + 24) : 0
        color: "transparent"
        visible: targetWorkspace !== -1 && dockHitbox.isPinned
        
        property int targetWorkspace: -1
        
        mask: Region {
            item: previewCard.active ? previewCard : null
        }

        WorkspacePreview {
            id: previewCard
            targetWorkspace: previewWindow.targetWorkspace
            
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: 72

            onCloseRequested: {
                previewWindow.targetWorkspace = -1;
            }
        }
    }
}
