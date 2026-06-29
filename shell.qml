import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
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

        // --- VISUAL LAYOUT CONTAINER ---
        ColumnLayout {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 40
            spacing: 20

            // Modules handle their internal loops, timers, and telemetry streams automatically
            ResourceRing { ringName: "CPU" }
            ResourceRing { ringName: "GPU" }
            ResourceRing { ringName: "RAM" }
            ResourceRing { ringName: "DISK" }
        }
    }

    // --- REFACTORED MODULAR COMPONENTS ---
    AppLauncher {
        id: appLauncherModule
    }

    // Changed from WallpaperWindow to match the new file name
    Wallpaper {
        id: wallpaperWindowModule
        rootShell: shellRoot
    }

    Dock {
        id: desktopDock
        launcherModule: appLauncherModule
        wallpaperModule: wallpaperWindowModule
    }
}