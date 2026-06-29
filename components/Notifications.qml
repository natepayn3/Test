import QtQuick

Column {
    id: notifRoot
    spacing: 8

    Text {
        text: "Notifications"
        color: "#ffffff"
        font.family: "Google Sans Flex"
        font.pixelSize: 13
        font.weight: Font.Bold
        // Bind to the model arriving from Dashboard.qml
        visible: dashboardWindow.notificationModel && dashboardWindow.notificationModel.length > 0
    }

    Column {
        width: parent.width
        spacing: 6

        Repeater {
            id: notifRepeater
            // Bind view directly to the global stream wrapper data
            model: dashboardWindow.notificationModel

            delegate: Rectangle {
                width: parent.width
                implicitHeight: 48
                radius: 8
                color: Qt.rgba(1, 1, 1, 0.05)

                Text {
                    id: closeBtn
                    text: "close"
                    font.family: "Material Symbols Outlined"
                    font.pixelSize: 14
                    color: "#ffffff"
                    opacity: 0.5
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 10
                    
                    MouseArea { anchors.fill: parent; onClicked: modelData.dismiss() }
                }

                Column {
                    anchors.left: parent.left
                    anchors.right: closeBtn.left
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.margins: 10
                    spacing: 0

                    Text { text: modelData.summary; color: "#ffffff"; font.family: "Google Sans Flex"; font.pixelSize: 12; font.weight: Font.Bold; elide: Text.ElideRight; width: parent.width }
                    Text { text: modelData.body; color: Qt.rgba(1, 1, 1, 0.5); font.family: "Google Sans Flex"; font.pixelSize: 10; elide: Text.ElideRight; width: parent.width }
                }
            }
        }
    }

    Text {
        text: "No active notifications"
        color: Qt.rgba(1, 1, 1, 0.3)
        font.family: "Google Sans Flex"
        font.pixelSize: 12
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        visible: !dashboardWindow.notificationModel || dashboardWindow.notificationModel.length === 0
    }
}