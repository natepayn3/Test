import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: dashboardWindow

    property var notificationModel: []

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-resource-dashboard"
    WlrLayershell.keyboardFocus: WlrLayershell.None
    exclusionMode: ExclusionMode.Ignore

    anchors {
        top: true
        bottom: true
        right: true
    }

    implicitWidth: 360
    color: "transparent"

    mask: Region {
        Region { item: hotspotTrigger }
        Region { item: dashHitbox.isPinned ? bgCard : null }
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
            width: 320
            height: Math.min(mainContentColumn.implicitHeight + 48, parent.height - 48)
            anchors.verticalCenter: parent.verticalCenter
            
            x: dashHitbox.isPinned ? (parent.width - width - 16) : parent.width
            opacity: dashHitbox.isPinned ? 1.0 : 0.0

            Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

            color: Qt.rgba(0, 0, 0, 0.01)
            border.width: 0
            radius: 16

            // Using a HoverHandler directly on the container tracks mouse positioning safely 
            // without creating a hit-mask block over interactive inner buttons
            HoverHandler {
                id: cardHover
            }

            ScrollView {
                id: dashScroll
                anchors.fill: parent
                // Ensures healthy padding buffers around your modules
                anchors.margins: 24
                clip: true
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                ScrollBar.vertical.policy: ScrollBar.AsNeeded

                // Standard Column enforces strict, consistent horizontal alignment bounds
                Column {
                    id: mainContentColumn
                    width: dashScroll.availableWidth
                    spacing: 24

                    Clock { width: parent.width }

                    Rectangle { width: parent.width; height: 1; color: Qt.rgba(1, 1, 1, 0.08) }

                    Weather { width: parent.width }

                    Rectangle { width: parent.width; height: 1; color: Qt.rgba(1, 1, 1, 0.08) }

                    ResourceRings { width: parent.width }

                    Rectangle { width: parent.width; height: 1; color: Qt.rgba(1, 1, 1, 0.08) }

                    VolumeSlider { width: parent.width }

                    Rectangle { width: parent.width; height: 1; color: Qt.rgba(1, 1, 1, 0.08) }

                    Media { width: parent.width }

                    Rectangle { width: parent.width; height: 1; color: Qt.rgba(1, 1, 1, 0.08) }

                    Notifications { width: parent.width }
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