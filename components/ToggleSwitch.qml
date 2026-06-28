import QtQuick

Rectangle {
    id: toggleRoot
    height: 48
    radius: height / 2

    property string label: ""
    property string iconName: ""
    property bool checked: false
    property bool isAvailable: true

    signal toggled()

    // 🎯 Use safe conditional evaluations checking for rootShell availability
    readonly property var txtColor: typeof rootShell !== "undefined" ? rootShell.colorText : "#f5f5f5"
    readonly property var bgColor: typeof rootShell !== "undefined" ? rootShell.colorBackground : "#1e1e24"
    readonly property var subColor: typeof rootShell !== "undefined" ? rootShell.colorSubtext : "#a6adc8"
    readonly property string fntFamily: typeof rootShell !== "undefined" ? rootShell.shellFont : "Sans"

    color: checked ? txtColor : Qt.rgba(txtColor.r, txtColor.g, txtColor.b, 0.15)
    opacity: isAvailable ? 1.0 : 0.5

    Text {
        text: toggleRoot.label
        font.family: toggleRoot.fntFamily
        font.pixelSize: 12
        font.bold: true
        color: toggleRoot.checked ? toggleRoot.bgColor : toggleRoot.txtColor
        anchors.verticalCenter: parent.verticalCenter
        
        x: toggleRoot.checked ? 6 : 46
        width: parent.width - 54 
        
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        
        Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.InOutQuad } }
        Behavior on color { ColorAnimation { duration: 200 } }
    }

    Rectangle {
        id: knob
        width: 40; height: 40; radius: 20
        color: toggleRoot.checked ? toggleRoot.bgColor : Qt.rgba(toggleRoot.txtColor.r, toggleRoot.txtColor.g, toggleRoot.txtColor.b, 0.2)
        anchors.verticalCenter: parent.verticalCenter
        x: toggleRoot.checked ? parent.width - width - 4 : 4

        Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.InOutQuad } }

        Text {
            anchors.centerIn: parent
            text: toggleRoot.iconName
            font.family: "Material Symbols Outlined"
            color: toggleRoot.checked ? toggleRoot.txtColor : toggleRoot.subColor
            font.pixelSize: 18
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: toggleRoot.isAvailable ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: if (toggleRoot.isAvailable) toggleRoot.toggled()
    }
}