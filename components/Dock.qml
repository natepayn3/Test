import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: dockWindow
    
    required property var launcherModule
    required property var wallpaperModule

    WlrLayershell.namespace: "quickshell-launcher"
    WlrLayershell.keyboardFocus: WlrLayershell.None

    // --- SYSTEM THEME MATRIX ---
    property color themeText: "#ffffff"
    property color themeBorder: Qt.rgba(1, 1, 1, 0.05)
    property color themeAccent: Qt.rgba(0.4, 0.4, 0.4, 0.28)
    property color hoverBorder: Qt.rgba(0, 0, 0, 0.2)

    anchors {
        bottom: true
        left: true
        right: true
    }
    
    implicitHeight: 85
    color: "transparent"
    exclusiveZone: 0

    Item {
        id: masterContainer
        width: visualDock.width + 40
        height: parent.height
        anchors.horizontalCenter: parent.horizontalCenter

        MouseArea {
            id: hotspotTrigger
            width: parent.width - 20
            height: 16
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            hoverEnabled: true
        }

        MouseArea {
            id: dockHitbox
            anchors.fill: parent
            hoverEnabled: true

            property int activeHoverIndex: -1

            property bool stableHover: hotspotTrigger.containsMouse ||
                                       dockHitbox.containsMouse || 
                                       (dockWindow.launcherModule && dockWindow.launcherModule.launcherWindowObject && dockWindow.launcherModule.launcherWindowObject.visible) ||
                                       (dockWindow.wallpaperModule && dockWindow.wallpaperModule.active)

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
                id: inputStabilizerCapsule
                width: visualDock.width + 24
                height: 72
                radius: 14
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: dockHitbox.isPinned ? 6 : -85
                color: Qt.rgba(0, 0, 0, 0.01) 

                Behavior on anchors.bottomMargin {
                    NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                }

                Row {
                    id: visualDock
                    spacing: 16
                    anchors.centerIn: parent 

                    // --- BUTTON 1: APP LAUNCHER ---
                    Item {
                        id: btnLauncher
                        width: 64
                        height: 64

                        Rectangle {
                            anchors.fill: parent
                            radius: 12
                            color: dockHitbox.activeHoverIndex === 0 ? dockWindow.themeAccent : "transparent"
                            border.color: dockHitbox.activeHoverIndex === 0 ? dockWindow.hoverBorder : "transparent"
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "apps"
                            font.family: "Material Symbols Outlined"
                            font.pixelSize: 32
                            style: Text.Outline
                            styleColor: Qt.rgba(0, 0, 0, 0.35)
                            color: dockHitbox.isPinned ? Qt.rgba(dockWindow.themeText.r, dockWindow.themeText.g, dockWindow.themeText.b, 0.9) : "transparent"
                            Behavior on color { ColorAnimation { duration: 180 } }
                        }
                    }

                    // --- BUTTON 2: WALLPAPER PICKER ---
                    Item {
                        id: btnWallpaper
                        width: 64
                        height: 64

                        Rectangle {
                            anchors.fill: parent
                            radius: 12
                            color: dockHitbox.activeHoverIndex === 1 ? dockWindow.themeAccent : "transparent"
                            border.color: dockHitbox.activeHoverIndex === 1 ? dockWindow.hoverBorder : "transparent"
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "wallpaper"
                            font.family: "Material Symbols Outlined"
                            font.pixelSize: 32
                            style: Text.Outline
                            styleColor: Qt.rgba(0, 0, 0, 0.35)
                            color: dockHitbox.isPinned ? Qt.rgba(dockWindow.themeText.r, dockWindow.themeText.g, dockWindow.themeText.b, 0.9) : "transparent"
                            Behavior on color { ColorAnimation { duration: 180 } }
                        }
                    }

                    // --- BUTTON 3: SCREENSHOT UTILITY ---
                    Item {
                        id: btnScreenshot
                        width: 64
                        height: 64

                        Rectangle {
                            anchors.fill: parent
                            radius: 12
                            color: dockHitbox.activeHoverIndex === 2 ? dockWindow.themeAccent : "transparent"
                            border.color: dockHitbox.activeHoverIndex === 2 ? dockWindow.hoverBorder : "transparent"
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "screenshot_region"
                            font.family: "Material Symbols Outlined"
                            font.pixelSize: 32
                            style: Text.Outline
                            styleColor: Qt.rgba(0, 0, 0, 0.35)
                            color: dockHitbox.isPinned ? Qt.rgba(dockWindow.themeText.r, dockWindow.themeText.g, dockWindow.themeText.b, 0.9) : "transparent"
                            Behavior on color { ColorAnimation { duration: 180 } }
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: dockHitbox.activeHoverIndex !== -1 ? Qt.PointingHandCursor : Qt.ArrowCursor

                    onPositionChanged: (mouse) => {
                        let adjustedX = mouse.x - 12; 
                        let totalCellWidth = 80; 
                        let calculatedIndex = Math.floor(adjustedX / totalCellWidth);
                        let localX = adjustedX % totalCellWidth;
                        
                        if (calculatedIndex >= 0 && calculatedIndex <= 2 && localX <= 64 && adjustedX >= 0) {
                            dockHitbox.activeHoverIndex = calculatedIndex;
                        } else {
                            dockHitbox.activeHoverIndex = -1;
                        }
                    }

                    onExited: dockHitbox.activeHoverIndex = -1

                    onClicked: (mouse) => {
                        if (dockHitbox.activeHoverIndex === 0) {
                            dockWindow.launcherModule.active = !dockWindow.launcherModule.active;
                        } else if (dockHitbox.activeHoverIndex === 1) {
                            if (dockWindow.wallpaperModule) {
                                dockWindow.wallpaperModule.active = !dockWindow.wallpaperModule.active;
                            }
                        } else if (dockHitbox.activeHoverIndex === 2) {
                            // Automatically lower the dock visibility flag to prevent visual clutter during region selection
                            dockHitbox.isPinned = false;
                            
                            // Native screenshot execution engine via grim, slurp, and satty
                            Quickshell.execDetached(["bash", "-c", "sleep 0.1 && grim -g \"$(slurp)\" -t ppm - | satty --filename -"]);
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
        }
    }
}
