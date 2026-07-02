import QtQuick
import "../../configs"

Column {
    id: clockRoot
    spacing: 2

    property date currentTime: new Date()

    Timer {
        interval: 1000
        running: clockRoot.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: clockRoot.currentTime = new Date()
    }

    FontConfig { id: fc }

    Text {
        text: Qt.formatDateTime(clockRoot.currentTime, "h:mm ap")
        font.family: fc.mainFont
        font.pixelSize: 46
        font.weight: Font.Bold
        color: "#ffffff"
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        
        Component.onCompleted: {
            fc.applyOutline(this, fc.overlayBackground)
        }
    }

    Text {
        text: Qt.formatDateTime(clockRoot.currentTime, "dddd • MMMM d")
        font.family: fc.mainFont
        font.pixelSize: 13
        font.weight: Font.Medium
        color: fc.textMuted
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        
        Component.onCompleted: {
            fc.applyOutline(this, fc.overlayBackground)
        }
    }
}