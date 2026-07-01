import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.SystemTray

PanelWindow {
    id: trayWindow

    WlrLayershell.namespace: "quickshell-launcher"
    WlrLayershell.keyboardFocus: WlrLayershell.None
    
    anchors {
        top: true
    }
    
    property int totalItemCount: SystemTray.items.values.length
    
    implicitWidth: totalItemCount === 0 ? 244 : (totalItemCount * 64) + ((totalItemCount - 1) * 16) + 48
    implicitHeight: 120 // Static canvas bounds matching Dock strategy
    color: "transparent"
    exclusiveZone: 0

    FontConfig { id: fc }
    ModuleConfig { id: shellConfig }

    // Mask strategy ported from Dock.qml to clip input area safely
    Item {
        id: staticMaskSurface
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: trayHitbox.isPinned ? 120 : 16
    }

    mask: Region {
        Region {
            item: staticMaskSurface
        }
    }

    property color themeText: shellConfig.themeText
    property color themeBorder: shellConfig.colorBorder
    property color themeAccent: shellConfig.themeAccent
    property color hoverBorder: shellConfig.hoverBorder

    property int activeHoverIndex: -1

    MouseArea {
        id: trayHitbox
        anchors.fill: parent
        hoverEnabled: true

        property bool isPinned: false
        property bool stableHover: hotspotTrigger.containsMouse || innerCapsuleMouseTracker.containsMouse

        onStableHoverChanged: {
            if (stableHover) {
                dismissTimer.stop();
                trayHitbox.isPinned = true;
            } else {
                dismissTimer.start();
            }
        }

        MouseArea {
            id: hotspotTrigger
            width: parent.width - 4
            height: 16
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            hoverEnabled: true
        }

        Rectangle {
            id: inputStabilizerCapsule
            width: parent.width - 24
            height: 72
            radius: shellConfig.radiusValue - 2
            anchors.horizontalCenter: parent.horizontalCenter
 
            // Slide mechanics inverted for top anchor but timings matched perfectly to Dock
            y: trayHitbox.isPinned ? 6 : -height
            color: shellConfig.colorBackground
            border.color: trayHitbox.isPinned ? shellConfig.colorBorder : "transparent"
            border.width: 1
            opacity: trayHitbox.isPinned ? 1.0 : 0.0

            Behavior on y { 
                NumberAnimation { duration: 180; easing.type: Easing.OutCubic } 
            }
            Behavior on opacity { 
                NumberAnimation { duration: 150; easing.type: Easing.OutQuad } 
            }

            Row {
                id: visualTrayCapsule
                spacing: 16
                anchors.centerIn: parent

                Item {
                    id: placeholderContainer
                    visible: trayWindow.totalItemCount === 0
                    width: 200
                    height: 64
                    
                    Text {
                        anchors.centerIn: parent
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        text: "blur_on"
                        font.family: fc.iconFont
                        font.pixelSize: 28
                        color: Qt.rgba(trayWindow.themeText.r, trayWindow.themeText.g, trayWindow.themeText.b, 0.35)
                        style: Text.Outline
                        styleColor: Qt.rgba(0, 0, 0, 0.35)
                    }
                }

                Repeater {
                    model: SystemTray.items.values
                    delegate: Item {
                        width: 64
                        height: 64
            
                        Rectangle {
                            anchors.fill: parent
                            radius: 12
                            color: trayWindow.activeHoverIndex === index ? (trayWindow.themeAccent || "transparent") : "transparent"
                            border.color: trayWindow.activeHoverIndex === index ? (trayWindow.hoverBorder || "transparent") : "transparent"
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }
      
                        Image {
                            anchors.centerIn: parent
                            width: 32
                            height: 32
                            source: modelData.iconPath ? "file://" + modelData.iconPath : "image://icon/" + (modelData.icon || "image-missing")
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            opacity: trayHitbox.isPinned ? 0.9 : 0.0
                            Behavior on opacity { NumberAnimation { duration: 180 } }
                        }

                        Rectangle {
                            id: tooltipBubble
                            visible: trayWindow.activeHoverIndex === index && modelData.title !== ""
                            width: tooltipText.contentWidth + 16
                            height: 26
                            radius: 6
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: parent.bottom
                            anchors.topMargin: 12
                            color: shellConfig.colorBackground || "#1e1e2e"
                            border.color: shellConfig.colorBorder || "#313244"
                            border.width: 1
                            z: 100

                            Text {
                                id: tooltipText
                                anchors.centerIn: parent
                                text: modelData.title || modelData.id || ""
                                font.pointSize: 10
                                font.weight: Font.Medium
                                color: trayWindow.themeText
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            cursorShape: Qt.PointingHandCursor

                            onEntered: trayWindow.activeHoverIndex = index
                            onExited: trayWindow.activeHoverIndex = -1

                            onClicked: (mouse) => {
                                if (mouse.button === Qt.RightButton) {
                                    modelData.secondaryActivate();
                                } else {
                                    modelData.activate();
                                }
                            }
                        }
                    }
                }
            }

            MouseArea {
                id: innerCapsuleMouseTracker
                anchors.fill: parent
                hoverEnabled: true
            }
        }
    }

    Timer {
        id: dismissTimer
        interval: 500
        running: false
        repeat: false
        onTriggered: {
            trayHitbox.isPinned = false;
            trayWindow.activeHoverIndex = -1;
        }
    }
}
