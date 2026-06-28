import QtQuick
import QtQuick.Shapes 
import Quickshell
import Quickshell.Wayland

ShellRoot {
    id: root

    readonly property color bgDarkGrey: "#1e1e24"
    readonly property int borderRadius: 16 
    readonly property int wingSize: 14

    // --- Screen Border Frame ---
    PanelWindow {
        id: frameWindowItem
        WlrLayershell.namespace: "quickshell-frame"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.exclusionMode: WlrLayershell.Ignore
        color: "transparent"
        mask: Region {} 

        anchors { left: true; right: true; top: true; bottom: true }

        Item {
            anchors.fill: parent
            layer.enabled: true
            layer.samples: 4
            
            Shape {
                anchors.fill: parent
                ShapePath {
                    fillColor: root.bgDarkGrey
                    strokeColor: "transparent"
                    fillRule: ShapePath.OddEvenFill
                    
                    PathMove { x: 0; y: 0 }
                    PathLine { x: frameWindowItem.width; y: 0 }
                    PathLine { x: frameWindowItem.width; y: frameWindowItem.height }
                    PathLine { x: 0; y: frameWindowItem.height }
                    PathLine { x: 0; y: 0 }
                    
                    PathMove { x: 8 + root.borderRadius; y: 8 }
                    PathLine { x: frameWindowItem.width - 8 - root.borderRadius; y: 8 }
                    PathArc { x: frameWindowItem.width - 8; y: 8 + root.borderRadius; radiusX: root.borderRadius; radiusY: root.borderRadius }
                    PathLine { x: frameWindowItem.width - 8; y: frameWindowItem.height - 8 - root.borderRadius }
                    PathArc { x: frameWindowItem.width - 8 - root.borderRadius; y: frameWindowItem.height - 8; radiusX: root.borderRadius; radiusY: root.borderRadius }
                    PathLine { x: 8 + root.borderRadius; y: frameWindowItem.height - 8 }
                    PathArc { x: 8; y: frameWindowItem.height - 8 - root.borderRadius; radiusX: root.borderRadius; radiusY: root.borderRadius }
                    PathLine { x: 8; y: 8 + root.borderRadius }
                    PathArc { x: 8 + root.borderRadius; y: 8; radiusX: root.borderRadius; radiusY: root.borderRadius }
                }
            }
        }
    }

    // --- Invisible 2/3 Height Left Edge Trigger ---
    PanelWindow {
        id: leftHoverTrigger
        WlrLayershell.namespace: "quickshell-hovertrigger"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.exclusionMode: WlrLayershell.Ignore
        color: "transparent"

        anchors { left: true; top: true; bottom: true }
        implicitWidth: 15 
        mask: Region { item: hoverTriggerZone }

        Item {
            id: hoverTriggerZone
            width: parent.width
            height: parent.height * (2 / 3)
            y: (parent.height - height) / 2

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onEntered: popupWindow.isOpen = true
            }
        }
    }

    // --- Pop-out Window ---
    PopupWindow {
        id: popupWindow
        implicitWidth: 300 + root.wingSize
        implicitHeight: 500 + (root.wingSize * 2)
        color: "transparent" 

        property bool isOpen: false
        visible: isOpen || styleWrapper.opacity > 0.01

        anchor {
            window: leftHoverTrigger
            rect.x: 8 - root.wingSize 
            rect.y: (leftHoverTrigger.height - popupWindow.implicitHeight) / 2
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onExited: popupWindow.isOpen = false

            // Instantiate stylized wrapper and inject custom dashboard panel content
            WindowStyle {
                id: styleWrapper
                isOpen: popupWindow.isOpen

                Dashboard {}
            }
        }
    }
}