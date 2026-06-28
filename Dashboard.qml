import QtQuick

Item {
    id: dashboardContainer
    anchors.fill: parent

    Rectangle {
        id: dashboardCard
        
        // Centers the card and forces a 10px margin gap on all sides
        anchors.centerIn: parent
        width: parent.width - 30
        height: parent.height - 30
        
        // Lighter gray surface fill
        color: "#2d2d34" 
        
        // Slightly scaled down radius to complement the outer 16px border elegantly
        radius: 12

        layer.enabled: true
        layer.smooth: true
        layer.samples: 4
        border.width: 0

        Text {
            anchors.centerIn: parent
            text: "Dashboard Content View"
            color: "#f5f5f5"
            font.pixelSize: 16
        }
    }
}