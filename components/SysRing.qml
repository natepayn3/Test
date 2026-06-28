import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes

Item {
    id: ringRoot
    Layout.fillWidth: true
    Layout.preferredHeight: 68

    property string label: ""
    property real value: 0.0
    property color ringColor: "#ffffff"

    readonly property real cleanVal: (!isFinite(value) || isNaN(value)) ? 0.0 : Math.max(0.0, Math.min(1.0, value))
    property real animatedSweep: cleanVal * 360
    Behavior on animatedSweep { NumberAnimation { duration: 300; easing.type: Easing.OutQuad } }

    Shape {
        width: 68; height: 68
        anchors.centerIn: parent
        layer.enabled: true
        layer.samples: 4
        
        ShapePath { 
            fillColor: "transparent"
            strokeColor: Qt.rgba(rootShell.colorText.r, rootShell.colorText.g, rootShell.colorText.b, 0.15)
            strokeWidth: 5; capStyle: ShapePath.RoundCap
            PathAngleArc { centerX: 34; centerY: 34; radiusX: 29; radiusY: 29; startAngle: 0; sweepAngle: 360 } 
        }
        ShapePath { 
            fillColor: "transparent"; strokeColor: ringRoot.ringColor; strokeWidth: 5; capStyle: ShapePath.RoundCap
            PathAngleArc { centerX: 34; centerY: 34; radiusX: 29; radiusY: 29; startAngle: -90; sweepAngle: ringRoot.animatedSweep } 
        }
        ColumnLayout {
            anchors.centerIn: parent; spacing: -2
            Text { text: Math.round(ringRoot.cleanVal * 100) + "%"; color: rootShell.colorText; font.family: rootShell.shellFont; font.bold: true; font.pixelSize: 13; Layout.alignment: Qt.AlignHCenter }
            Text { text: ringRoot.label; color: rootShell.colorSubtext; font.family: rootShell.shellFont; font.pixelSize: 9; Layout.alignment: Qt.AlignHCenter }
        }
    }
}
