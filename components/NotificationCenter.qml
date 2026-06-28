import QtQuick
import QtQuick.Layouts

Rectangle {
    id: notifRoot
    color: Qt.rgba(0, 0, 0, 0.15)
    radius: 12
    clip: true

    property var notificationModel: notifServer.trackedNotifications

    // Dynamically calculate footprint based on content
    implicitHeight: notifList.count <= 0 ? 80 : (notifList.count === 1 ? 132 : 204)
    Behavior on implicitHeight { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        // Header Row (Only shows "Clear all" when there are notifications)
        RowLayout {
            Layout.fillWidth: true
            visible: notifList.count > 0 
            
            Item { Layout.fillWidth: true } 
            
            Item {
                implicitWidth: clearText.width + 8; implicitHeight: 10
                
                Text { 
                    id: clearText
                    text: "Clear all"
                    font.family: rootShell.shellFont
                    font.pixelSize: 12
                    font.bold: true
                    anchors.centerIn: parent
                    color: clearMouse.containsMouse ? rootShell.colorText : rootShell.colorAccent 
                }
                
                MouseArea {
                    id: clearMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    
                    onClicked: {
                        let arr = notifRoot.notificationModel.values;
                        if (arr && arr.length > 0) {
                            for (let i = arr.length - 1; i >= 0; i--) {
                                if (arr[i]) arr[i].dismiss();
                            }
                        }
                    }
                }
            }
        }

        // Empty State
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: notifList.count === 0

            Text { 
                text: "No notifications" 
                anchors.centerIn: parent 
                font.family: rootShell.shellFont 
                color: rootShell.colorSubtext 
                font.pixelSize: 13 
            }
        }

        // Notification Stream View
        ListView {
            id: notifList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 8
            model: notifRoot.notificationModel
            visible: count > 0

            remove: Transition { ParallelAnimation { NumberAnimation { property: "opacity"; to: 0; duration: 200 } } }
            displaced: Transition { NumberAnimation { properties: "y"; duration: 250; easing.type: Easing.OutCubic } }

            delegate: Rectangle {
                required property var modelData
                width: notifList.width
                height: 64
                radius: 8
                color: Qt.rgba(rootShell.colorText.r, rootShell.colorText.g, rootShell.colorText.b, 0.05)
                
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 12
                    
                    Rectangle {
                        width: 40; height: 40; radius: 8; color: Qt.rgba(rootShell.colorText.r, rootShell.colorText.g, rootShell.colorText.b, 0.1)
                        Text { anchors.centerIn: parent; text: "notifications"; font.family: "Material Symbols Outlined"; color: rootShell.colorText; font.pixelSize: 20; visible: notifImg.status !== Image.Ready }
                        Image { id: notifImg; anchors.fill: parent; anchors.margins: 4; source: (modelData.image && modelData.image.startsWith("/")) ? modelData.image : ""; visible: source !== ""; fillMode: Image.PreserveAspectFit }
                    }
                    ColumnLayout {
                        spacing: 2; Layout.fillWidth: true
                        Text { text: modelData.summary; color: rootShell.colorText; font.family: rootShell.shellFont; font.bold: true; font.pixelSize: 13; elide: Text.ElideRight; Layout.fillWidth: true }
                        Text { text: modelData.body; color: rootShell.colorSubtext; font.family: rootShell.shellFont; font.pixelSize: 11; elide: Text.ElideRight; maximumLineCount: 1; Layout.fillWidth: true }
                    }
                    MouseArea { 
                        width: 24; height: 24; cursorShape: Qt.PointingHandCursor; onClicked: modelData.dismiss()
                        Text { anchors.centerIn: parent; text: "close"; font.family: "Material Symbols Outlined"; color: rootShell.colorSubtext; font.pixelSize: 16 }
                    }
                }
            }
        }
    }
}
