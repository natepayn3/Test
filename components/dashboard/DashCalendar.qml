import QtQuick
import QtQuick.Layouts
import "../../configs"

ColumnLayout {
    id: calRoot
    spacing: 6

    property date currentDate: new Date()
    property date displayDate: new Date(currentDate.getFullYear(), currentDate.getMonth(), 1)
    
    property int firstDayOffset: new Date(displayDate.getFullYear(), displayDate.getMonth(), 1).getDay()
    property int daysInMonth: new Date(displayDate.getFullYear(), displayDate.getMonth() + 1, 0).getDate()

    FontConfig { id: fc }

    // --- CALENDAR HEADER (Month & Year) ---
    Text {
        text: Qt.formatDate(calRoot.displayDate, "MMMM yyyy")
        color: "#ffffff"
        font.family: fc.mainFont
        font.pixelSize: 13
        font.weight: Font.Bold
        Layout.fillWidth: true
        horizontalAlignment: Text.AlignHCenter

        Component.onCompleted: {
            fc.applyOutline(this, fc.overlayBackground)
        }
    }

    // --- UNIFIED GRID ENGINE (Labels + Dates) ---
    GridLayout {
        id: calendarGrid
        Layout.fillWidth: true
        columns: 7
        rowSpacing: 4
        columnSpacing: 0

        // 1. Day of Week Labels (First row of the grid)
        Repeater {
            model: ["S", "M", "T", "W", "T", "F", "S"]
            delegate: Item {
                Layout.fillWidth: true
                implicitHeight: 14
                
                Text {
                    anchors.centerIn: parent
                    text: modelData
                    color: fc.textMuted
                    font.family: fc.mainFont
                    font.pixelSize: 10
                    font.weight: Font.Bold
                    
                    Component.onCompleted: {
                        fc.applyOutline(this, fc.overlayBackground)
                    }
                }
            }
        }

        // 2. Date Cells (Subsequent rows)
        Repeater {
            model: 42 
            
            delegate: Item {
                id: cellItem
                Layout.fillWidth: true
                implicitHeight: 18 

                property int dayNumber: index + 1 - calRoot.firstDayOffset
                property bool isValidDay: dayNumber > 0 && dayNumber <= calRoot.daysInMonth
                property bool isToday: isValidDay && 
                                       dayNumber === calRoot.currentDate.getDate() && 
                                       calRoot.displayDate.getMonth() === calRoot.currentDate.getMonth() && 
                                       calRoot.displayDate.getFullYear() === calRoot.currentDate.getFullYear()

                Text {
                    anchors.centerIn: parent
                    text: parent.isValidDay ? parent.dayNumber : ""
                    color: parent.isToday ? "#ffffff" : Qt.rgba(1, 1, 1, 0.75)
                    font.family: fc.mainFont
                    font.pixelSize: parent.isToday ? 13 : 11
                    font.weight: parent.isToday ? Font.Bold : Font.Normal
                    opacity: parent.isValidDay ? 1.0 : 0.0
                    
                    Component.onCompleted: {
                        if (parent.isValidDay && !parent.isToday) {
                            fc.applyOutline(this, fc.overlayBackground)
                        } else if (parent.isToday) {
                            fc.applyOutline(this, fc.overlayBackground)
                        }
                    }
                }
            }
        }
    }
}