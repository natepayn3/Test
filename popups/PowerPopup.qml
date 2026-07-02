import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import "../configs"

PanelWindow {
    id: powerPopupWindow

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-launcher"
    WlrLayershell.keyboardFocus: visible ? WlrLayershell.OnDemand : WlrLayershell.None
    exclusionMode: ExclusionMode.Ignore

    anchors {
        bottom: true
        top: true
        left: true
        right: true
    }
    
    color: "transparent"

    property color colorBackground: shellConfig.colorBackground
    property color colorBorder: shellConfig.colorBorder
    property color themeText: shellConfig.themeText

    property bool animateActive: false
    property int activeHoverIndex: -1

    FontConfig { id: fc }

    MouseArea {
        id: outsideDismiss
        anchors.fill: parent
        onClicked: powerPopupWindow.animateActive = false 

        Rectangle {
            id: bgCard
            width: 360
            height: mainLayout.implicitHeight + 40
           
            transformOrigin: Item.Center
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 100
            anchors.horizontalCenter: parent.horizontalCenter
           
            color: powerPopupWindow.colorBackground
            border.color: powerPopupWindow.colorBorder
            border.width: 1
         
            radius: shellConfig.radiusValue

            // --- Standalone Left Side Power Icon ---
            Text {
                id: leftPowerIcon
                text: "electrical_services"
                font.family: fc.iconFont
                font.pixelSize: 125
                color: fc.overlayBackground
                styleColor: colorBackground
                
                anchors.right: parent.left
                anchors.rightMargin: -10
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: 0
                transform: Scale { 
                    origin.x: leftPowerIcon.width / 2
                    xScale: -1 
                }
                
                Component.onCompleted: fc.applySmoothing(this)
            }

            // --- Standalone Right Side Power Icon ---
            Text {
                id: rightPowerIcon
                text: "electrical_services"
                font.family: fc.iconFont
                font.pixelSize: 125
                color: fc.overlayBackground
                styleColor: colorBackground

                anchors.left: parent.right
                anchors.leftMargin: -10
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: 0
                
                Component.onCompleted: fc.applySmoothing(this)
            }

            states: [
                State {
                    name: "hidden"
                    when: !powerPopupWindow.animateActive
                    PropertyChanges { target: bgCard; opacity: 0.0; scale: 0.3 }
                },
                State {
                    name: "shown"
                    when: powerPopupWindow.animateActive
                    PropertyChanges { target: bgCard; opacity: 1.0; scale: 1.0 }
                }
            ]

            transitions: [
                Transition {
                    from: "hidden"; to: "shown"
                    ParallelAnimation {
                        NumberAnimation { target: bgCard; property: "scale"; duration: shellConfig.durationIn; easing.type: Easing.OutBack; easing.amplitude: shellConfig.springBack }
                        NumberAnimation { target: bgCard; property: "opacity"; duration: shellConfig.opacityIn; easing.type: Easing.OutQuad }
                    }
                },
                Transition {
                    from: "shown"; to: "hidden"
                    SequentialAnimation {
                        ParallelAnimation {
                            NumberAnimation { target: bgCard; property: "scale"; duration: shellConfig.durationOut; easing.type: Easing.InBack; easing.amplitude: shellConfig.springIn }
                            NumberAnimation { target: bgCard; property: "opacity"; duration: shellConfig.opacityOut; easing.type: Easing.InQuad }
                        }
                        ScriptAction { script: powerPopupWindow.visible = false }
                    }
                }
            ]

            MouseArea {
                anchors.fill: parent
                onClicked: (mouse) => mouse.accepted = true
            }

            ColumnLayout {
                id: mainLayout
                anchors.fill: parent
                anchors.margins: 22
                spacing: 20

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: "Power Options"
                        color: fc.textPrimary
                        font.family: fc.mainFont
                        font.pixelSize: 18
                        font.weight: Font.Bold
                        Layout.fillWidth: true
                        
                        Component.onCompleted: fc.applyOutline(this)
                    }
                }

                RowLayout {
                    id: actionRow
                    Layout.fillWidth: true
                    spacing: 12

                    Repeater {
                        model: [
                            { icon: "bedtime", label: "Suspend", cmd: ["systemctl", "suspend"] },
                            { icon: "logout", label: "Log Out", cmd: ["hyprctl", "dispatch", "hl.dsp.exit()"] },
                            { icon: "restart_alt", label: "Reboot", cmd: ["systemctl", "reboot"] },
                            { icon: "power_settings_new", label: "Power Off", cmd: ["systemctl", "poweroff"] }
                        ]

                        delegate: Rectangle {
                            id: actionBtn
                            Layout.fillWidth: true
                            Layout.preferredHeight: 64
                            radius: 12
                            
                            color: powerPopupWindow.activeHoverIndex === index 
                                ? powerPopupWindow.colorBackground 
                                : fc.trackBackground
                            border.color: powerPopupWindow.activeHoverIndex === index ? shellConfig.hoverBorder : "transparent"
                            border.width: 1

                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 2

                                Text {
                                    text: modelData.icon
                                    font.family: fc.iconFont
                                    font.pixelSize: 24
                                    color: fc.textPrimary
                                    Layout.alignment: Qt.AlignHCenter
                                    
                                    Component.onCompleted: fc.applyOutline(this)
                                }
                            }

                            HoverHandler {
                                onHoveredChanged: {
                                    if (hovered) powerPopupWindow.activeHoverIndex = index;
                                    else if (powerPopupWindow.activeHoverIndex === index) powerPopupWindow.activeHoverIndex = -1;
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    powerPopupWindow.animateActive = false;
                                    Quickshell.execDetached(modelData.cmd);
                                }
                            }
                        }
                    }
                }
            }
        }

        focus: true
        Keys.onEscapePressed: powerPopupWindow.animateActive = false
    }

    onVisibleChanged: {
        if (visible) {
            outsideDismiss.forceActiveFocus();
            powerPopupWindow.animateActive = true;
        } else {
            powerPopupWindow.animateActive = false;
        }
    }
}