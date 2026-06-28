import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "components"

ShellRoot {
    id: shellRoot

    // --- BACKGROUND METRICS WINDOW ---
    PanelWindow {
        id: window
        
        anchors {
            right: true
            bottom: true
        }
        
        implicitWidth: 150
        implicitHeight: 500
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Background
        exclusionMode: ExclusionMode.Ignore

        // --- STREAMING ENGINES ---
        Process {
            id: cpuProc
            command: ["sh", "-c", "while true; do head -n1 /proc/stat; sleep 1; done"]
            running: true
            
            property real prevTotal: 0
            property real prevIdle: 0

            stdout: SplitParser {
                onRead: data => {
                    let parts = data.trim().split(/\s+/);
                    if (parts.length < 5) return;
                    
                    let user = parseFloat(parts[1]);
                    let nice = parseFloat(parts[2]);
                    let system = parseFloat(parts[3]);
                    let idle = parseFloat(parts[4]);
                    
                    let work = user + nice + system;
                    let total = work + idle;
                    
                    let diffWork = work - cpuProc.prevTotal;
                    let diffTotal = total - cpuProc.prevIdle;
                    
                    if (diffTotal > 0) {
                        cpuRing.value = Math.max(0.0, Math.min(1.0, diffWork / diffTotal));
                    }
                    
                    cpuProc.prevTotal = work;
                    cpuProc.prevIdle = total;
                }
            }
        }

        Process {
            id: gpuProc
            command: ["nvidia-smi", "--query-gpu=utilization.gpu", "--format=csv,noheader,nounits", "-l", "1"]
            running: true
            stdout: SplitParser {
                onRead: data => {
                    let val = parseFloat(data.trim());
                    if (!isNaN(val)) gpuRing.value = val / 100.0;
                }
            }
        }

        Process {
            id: ramProc
            command: ["sh", "-c", "while true; do grep -E 'MemTotal|MemAvailable' /proc/meminfo; sleep 1; done"]
            running: true
            
            property real totalMem: 1

            stdout: SplitParser {
                onRead: data => {
                    let line = data.trim();
                    let val = parseFloat(line.replace(/[^0-9]/g, ''));
                    if (isNaN(val)) return;

                    if (line.includes("MemTotal:")) {
                        ramProc.totalMem = val;
                    } else if (line.includes("MemAvailable:")) {
                        ramRing.value = (ramProc.totalMem - val) / ramProc.totalMem;
                    }
                }
            }
        }

        Process {
            id: diskProc
            command: ["sh", "-c", "df --output=pcent / | tail -n 1 | tr -d ' %'"]
            running: false
            
            stdout: SplitParser {
                onRead: data => {
                    let pcent = parseFloat(data.trim());
                    if (!isNaN(pcent)) {
                        diskRing.value = pcent / 100.0;
                    }
                }
            }
        }

        Timer {
            id: diskTimer
            interval: 3600000
            running: true
            repeat: true
            triggeredOnStart: true
            onTriggered: {
                diskProc.running = false;
                diskProc.running = true;
            }
        }

        // --- VISUAL LAYOUT CONTAINER ---
        ColumnLayout {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 40
            spacing: 20

            ResourceRing { id: cpuRing; ringName: "CPU"; value: 0.0 }
            ResourceRing { id: gpuRing; ringName: "GPU"; value: 0.0 }
            ResourceRing { id: ramRing; ringName: "RAM"; value: 0.0 }
            ResourceRing { id: diskRing; ringName: "DISK"; value: 0.0 }
        }
    }

    // --- BOTTOM HOTSPOT ANCHOR WINDOW ---
    PanelWindow {
        id: launcherAnchor
        
        anchors {
            bottom: true
            left: true
            right: true
        }
        
        implicitHeight: 65
        color: "transparent"
        
        exclusiveZone: 0

        // Clickthrough Mask: Directs the compositor to only register clicks inside the visual dock bounds
        mask: Region {
            item: masterContainer
        }

        Item {
            id: masterContainer
            width: 240
            height: parent.height
            anchors.horizontalCenter: parent.horizontalCenter

            // Invisible tracking target fixed at the absolute bottom edge of the screen
            MouseArea {
                id: hotspotTrigger
                width: 220
                height: 12
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                hoverEnabled: true
            }

            // --- TRANSPARENT DOCK CONTAINER ---
            MouseArea {
                id: dockHitbox
                width: visualDock.width + 20 
                height: 60
                anchors.horizontalCenter: parent.horizontalCenter
                hoverEnabled: true

                property bool isPinned: hotspotTrigger.containsMouse || 
                                        dockHitbox.containsMouse || 
                                        appLauncherModule.launcherWindowObject.visible

                anchors.bottom: parent.bottom
                anchors.bottomMargin: isPinned ? 6 : -65

                Behavior on anchors.bottomMargin {
                    NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                }

                Row {
                    id: visualDock
                    spacing: 12
                    anchors.centerIn: parent 

                    // --- BUTTON 1: APP LAUNCHER ---
                    Rectangle {
                        id: btnLauncher
                        width: 55
                        height: 55
                        radius: 12
                        color: mouseLauncher.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(1, 1, 1, 0.05)
                        Behavior on color { ColorAnimation { duration: 150 } }

                        Text {
                            anchors.centerIn: parent
                            text: "apps"
                            font.family: "Material Symbols Outlined"
                            font.pixelSize: 26
                            color: dockHitbox.isPinned ? Qt.rgba(1, 1, 1, 0.85) : Qt.rgba(1, 1, 1, 0.0)
                            Behavior on color { ColorAnimation { duration: 180 } }
                        }

                        MouseArea {
                            id: mouseLauncher
                            anchors.fill: parent
                            hoverEnabled: true
                            
                            // Fixed: Control the state flag exposed on the Scope container directly
                            onClicked: appLauncherModule.active = !appLauncherModule.active
                        }
                    }

                    // --- BUTTON 2: WALLPAPER PICKER (STUB) ---
                    Rectangle {
                        id: btnWallpaper
                        width: 55
                        height: 55
                        radius: 12
                        color: mouseWallpaper.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(1, 1, 1, 0.05)
                        Behavior on color { ColorAnimation { duration: 150 } }

                        Text {
                            anchors.centerIn: parent
                            text: "wallpaper"
                            font.family: "Material Symbols Outlined"
                            font.pixelSize: 26
                            color: dockHitbox.isPinned ? Qt.rgba(1, 1, 1, 0.85) : Qt.rgba(1, 1, 1, 0.0)
                            Behavior on color { ColorAnimation { duration: 180 } }
                        }

                        MouseArea {
                            id: mouseWallpaper
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: console.log("Wallpaper Picker Action Triggered")
                        }
                    }

                    // --- BUTTON 3: SCREENSHOT UTILITY (STUB) ---
                    Rectangle {
                        id: btnScreenshot
                        width: 55
                        height: 55
                        radius: 12
                        color: mouseScreenshot.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(1, 1, 1, 0.05)
                        Behavior on color { ColorAnimation { duration: 150 } }

                        Text {
                            anchors.centerIn: parent
                            text: "screenshot_region"
                            font.family: "Material Symbols Outlined"
                            font.pixelSize: 26
                            color: dockHitbox.isPinned ? Qt.rgba(1, 1, 1, 0.85) : Qt.rgba(1, 1, 1, 0.0)
                            Behavior on color { ColorAnimation { duration: 180 } }
                        }

                        MouseArea {
                            id: mouseScreenshot
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: console.log("Screenshot Tool Action Triggered")
                        }
                    }
                }
            }
        }
    }

    // Full-screen launcher overlay instantiation
    AppLauncher {
        id: appLauncherModule
    }
}
