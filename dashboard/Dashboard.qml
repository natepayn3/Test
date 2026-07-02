import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import QtQuick.Shapes
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Notifications
import "../../configs"

PanelWindow {
    id: dashboardWindow

    FontConfig { id: fc }

    property var notificationModel: notifServer.trackedNotifications

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-resource-dashboard"
    WlrLayershell.keyboardFocus: WlrLayershell.None
    exclusionMode: ExclusionMode.Ignore

    anchors {
        top: true
        bottom: true
        right: true
    }

    implicitWidth: 450
    color: "transparent"

    property bool wifiAvailable: false
    property bool wifiActive: false
    property bool btActive: false
    property bool caffeineActive: false

    property bool dndActive: false
    signal dndToggled()

    NotificationServer {
        id: notifServer
        bodySupported: true
        actionsSupported: true
        imageSupported: true
        persistenceSupported: true
        onNotification: (notif) => {
            if (!dashboardWindow.dndActive) notif.tracked = true;
            else notif.dismiss();
        }
    }

    Process { id: wifiToggleProc; running: false }
    Process { id: btToggleProc; running: false }
    Process { id: caffeineToggleProc; running: false }

    Timer {
        id: statePoller
        interval: 3000
        running: dashboardWindow.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            wifiStateCheck.running = true;
            btStateCheck.running = true;
            checkHypridleProc.running = true;
        }
    }

    Process {
        id: wifiStateCheck
        command: ["sh", "-c", "nmcli -t -f TYPE,STATE device | grep -q '^wifi:' && echo 'AVAILABLE' || echo 'MISSING'; nmcli radio wifi"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                let lines = this.text.trim().split("\n");
                if (lines.length >= 1) dashboardWindow.wifiAvailable = (lines[0] === "AVAILABLE");
                if (lines.length >= 2) dashboardWindow.wifiActive = dashboardWindow.wifiAvailable && (lines[1].trim() === "enabled");
                wifiStateCheck.running = false;
            }
        }
    }

    Process {
        id: btStateCheck
        command: ["sh", "-c", "bluetoothctl show | grep -q 'Powered: yes' && echo 'ON' || echo 'OFF'"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                dashboardWindow.btActive = (this.text.trim() === "ON");
                btStateCheck.running = false;
            }
        }
    }

    Process {
        id: checkHypridleProc
        command: ["pgrep", "-x", "hypridle"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                dashboardWindow.caffeineActive = (this.text.trim() === "");
                checkHypridleProc.running = false;
            }
        }
    }

    mask: Region {
        Region { item: hotspotTrigger }
        Region { item: dashHitbox.isPinned ? bgCard : null }
        Region { item: dashHitbox.isPinned ? leftDashboardIcon : null }
    }

    MouseArea {
        id: dashHitbox
        anchors.fill: parent
        hoverEnabled: true

        property bool stableHover: hotspotTrigger.containsMouse || cardHover.hovered
        property bool isPinned: false

        onStableHoverChanged: {
            if (stableHover) {
                dismissTimer.stop();
                isPinned = true;
            } else {
                dismissTimer.start();
            }
        }

        MouseArea {
            id: hotspotTrigger
            width: 16
            height: parent.height
            anchors.right: parent.right
            hoverEnabled: true
        }

        Rectangle {
            id: bgCard
            width: 360
            height: contentGrid.implicitHeight + (contentGrid.anchors.margins * 2)
            anchors.verticalCenter: parent.verticalCenter
            
            x: dashHitbox.isPinned ? (parent.width - width - 16) : parent.width
            opacity: dashHitbox.isPinned ? 1.0 : 0.0

            Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

            color: shellConfig.colorBackground
            border.color: shellConfig.colorBorder
            border.width: 1
            radius: shellConfig.radiusValue

            // --- Standalone Top App Icon ---
            Text {
                id: topDashboardIcon
                text: "drag_handle"
                font.family: fc.iconFont
                font.pixelSize: 50
                color: shellConfig.themeBackground
                styleColor: shellConfig.colorBackground
                anchors.bottom: parent.top
                anchors.bottomMargin: -20
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.horizontalCenterOffset: 0
            }

            // --- Standalone Left App Icon ---
            Text {
                id: leftDashboardIcon
                text: "more"
                font.family: fc.iconFont
                font.pixelSize: 75
                color: shellConfig.themeBackground
                styleColor: shellConfig.colorBackground
                anchors.right: parent.left
                anchors.rightMargin: -2
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: 0
            }

            // --- Standalone Bottom App Icon ---
            Text {
                id: bottomDashboardIcon
                text: "drag_handle"
                font.family: fc.iconFont
                font.pixelSize: 50
                color: shellConfig.themeBackground
                styleColor: shellConfig.colorBackground
                anchors.top: parent.bottom
                anchors.topMargin: -20
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.horizontalCenterOffset: 0
            }

            HoverHandler { id: cardHover }

            ColumnLayout {
                id: contentGrid
                anchors.fill: parent
                anchors.margins: 24
                spacing: 20

                RowLayout {
                    id: contentGridRow
                    Layout.fillWidth: true
                    spacing: 16

                    ColumnLayout {
                        id: leftColumn
                        Layout.fillWidth: true
                        spacing: 20

                        Clock { 
                            Layout.fillWidth: true
                            Component.onCompleted: {
                                for (let i = 0; i < children.length; i++) {
                                    if (children[i].horizontalAlignment !== undefined) {
                                        children[i].horizontalAlignment = Text.AlignHCenter;
                                    }
                                }
                            }
                        }
                        
                        RowLayout {
                            id: weatherCalendarRow
                            Layout.fillWidth: true
                            spacing: 12

                            Weather { 
                                Layout.fillWidth: true
                                Layout.preferredWidth: 40
                                Layout.alignment: Qt.AlignTop
                                
                                Component.onCompleted: {
                                    for (let i = 0; i < children.length; i++) {
                                        if (children[i].horizontalAlignment !== undefined) {
                                            children[i].horizontalAlignment = Text.AlignHCenter;
                                        }
                                    }
                                }
                            }

                            DashCalendar {
                                Layout.fillWidth: true
                                Layout.preferredWidth: 60
                                Layout.alignment: Qt.AlignTop
                            }
                        }
                        
                        VolumeSlider { 
                            Layout.fillWidth: true
                            Layout.topMargin: -12
                        }

                        BrightnessSlider { 
                            Layout.fillWidth: true
                            Layout.topMargin: 0
                        }

                        BatterySlider {
                            Layout.fillWidth: true
                            Layout.topMargin: 0
                        }
                    }

                    ColumnLayout {
                        id: rightColumn
                        Layout.preferredWidth: 84
                        Layout.fillHeight: true
                        spacing: 0

                        ResourceRings {
                            Layout.fillHeight: true
                            Layout.fillWidth: true
                        }
                    }
                }

                Toggles {
                    Layout.fillWidth: true
                    
                    wifiAvailable: dashboardWindow.wifiAvailable
                    wifiActive: dashboardWindow.wifiActive
                    btActive: dashboardWindow.btActive
                    caffeineActive: dashboardWindow.caffeineActive

                    dndActive: dashboardWindow.dndActive

                    onDndToggled: dashboardWindow.dndToggled()

                    onWifiToggled: {
                        dashboardWindow.wifiActive = !dashboardWindow.wifiActive
                        wifiToggleProc.command = ["sh", "-c", "nmcli radio wifi | grep -q enabled && nmcli radio wifi off || nmcli radio wifi on"]
                        wifiToggleProc.running = true
                    }
                    onBtToggled: {
                        dashboardWindow.btActive = !dashboardWindow.btActive
                        btToggleProc.command = ["sh", "-c", "bluetoothctl show | grep -q 'Powered: yes' && bluetoothctl power off || bluetoothctl power on"]
                        btToggleProc.running = true
                    }
                    onCaffeineToggled: {
                        dashboardWindow.caffeineActive = !dashboardWindow.caffeineActive
                        caffeineToggleProc.command = dashboardWindow.caffeineActive 
                            ? ["pkill", "-x", "hypridle"]
                            : ["hyprctl", "dispatch", "hl.dsp.exec_cmd('hypridle')"];
                        caffeineToggleProc.running = true
                    }
                }

                Item {
                    id: mediaWrapper
                    Layout.fillWidth: true
                    implicitHeight: childrenRect.height

                    Media { 
                        width: parent.width
                    }
                }

                Item {
                    id: notifWrapper
                    Layout.fillWidth: true
                    implicitHeight: childrenRect.height

                    Notifications { 
                        width: parent.width
                    }
                }
            }
        }
    }

    Timer {
        id: dismissTimer
        interval: 350
        running: false
        repeat: false
        onTriggered: dashHitbox.isPinned = false
    }
}
