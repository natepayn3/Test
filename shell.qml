import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications
import "components"

ShellRoot {
    id: shellRoot
    
    property bool audioPopupActive: false
    property var activeNotifications: []
    property bool dndActive: false

    QtObject {
        id: notifBroadcaster
        signal broadcast(string summary, string body)
    }

    ModuleConfig { id: shellConfig }

    AppLauncher { id: appLauncherModule }
    Wallpaper { id: wallpaperWindowModule; rootShell: shellRoot }

    NotificationServer {
        id: notifServer
        bodySupported: true
        actionsSupported: false
        
        onNotification: (notification) => {
            notifBroadcaster.broadcast(notification.summary, notification.body);
        }
    }

    // --- MONITOR REPEATERS ---
    Variants {
        model: Quickshell.screens
        Dock {
            required property var modelData
            screen: modelData
            launcherModule: appLauncherModule
            wallpaperModule: wallpaperWindowModule
        }
    }

    Variants {
        model: Quickshell.screens
        WorkspaceDock {
            required property var modelData
            screen: modelData
        }
    }

    Variants {
        model: Quickshell.screens
        Dashboard {
            required property var modelData
            screen: modelData
            notificationModel: notifServer.trackedNotifications.values
            dndActive: shellRoot.dndActive
            onDndToggled: shellRoot.dndActive = !shellRoot.dndActive
        }
    }

    Variants {
        model: Quickshell.screens
        VolumeOsd {
            required property var modelData
            screen: modelData
        }
    }

    Variants {
        model: Quickshell.screens
        NotificationOsd {
            required property var modelData
            screen: modelData
            broadcaster: notifBroadcaster
            dndActive: shellRoot.dndActive
        }
    }
}
