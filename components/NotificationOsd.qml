import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../configs"

PanelWindow {
    id: popupWindow

    required property var screen
    required property var broadcaster
    property bool dndActive: false

    FontConfig {
        id: fc
    }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-notification-osd"
    WlrLayershell.keyboardFocus: WlrLayershell.None
    exclusionMode: ExclusionMode.Ignore

    visible: notifModel.count > 0

    anchors.top: true
    anchors.bottom: true
    anchors.right: true
    
    margins.bottom: 100
    margins.right: 24

    implicitWidth: 360
    implicitHeight: 500
    color: "transparent"

    ListModel {
        id: notifModel
    }

    Connections {
        target: popupWindow.broadcaster

        function onBroadcast(summary, body) {
            if (popupWindow.dndActive) { // 💡 Read from the local property tracking shellRoot
                return;
            }

            let itemKey = Date.now() + "_" + Math.random();
            notifModel.append({
                "key": itemKey,
                "summary": summary,
                "body": body
            });
            let autoDismiss = Qt.createQmlObject('import QtQuick; Timer { interval: 3000; repeat: false }', popupWindow);
            autoDismiss.triggered.connect(function() {
                for (let i = 0; i < notifModel.count; i++) {
                    if (notifModel.get(i).key === itemKey) {
                        notifModel.remove(i);
                        break;
                    }
                }
                autoDismiss.destroy();
            });
            autoDismiss.start();
        }
    }

    ListView {
        id: stackView
        anchors.fill: parent
        model: notifModel
        spacing: 12 
        interactive: false 
        verticalLayoutDirection: ListView.BottomToTop 

        delegate: Item {
            width: stackView.width
            height: 64 

            Rectangle {
                id: bannerCard
                anchors.fill: parent
                radius: 16
                color: Qt.rgba(0, 0, 0, 0.01) 
                border.color: Qt.rgba(1, 1, 1, 0.05)
                border.width: 1

                RowLayout {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 22
                    anchors.rightMargin: 22
                    spacing: 18

                    Rectangle {
                        width: 28
                        height: 28
                        radius: 6
                        color: Qt.rgba(1, 1, 1, 0.06)
                        Layout.alignment: Qt.AlignVCenter

                        Text {
                            id: iconText
                            anchors.centerIn: parent
                            text: "notifications_unread"
                            font.family: fc.iconFont
                            font.pixelSize: 25
                            color: "#ffffff"
                           
                            Component.onCompleted: {
                                fc.applyOutline(this, Qt.rgba(0, 0, 0, 0.35))
                            }
                        }
                    }

                    ColumnLayout {
                        spacing: 2
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter

                        Text {
                            id: summaryText
                            text: model.summary
                            color: "#ffffff"
                            font.family: fc.mainFont
                            font.pixelSize: 15
                            font.weight: Font.Bold
                            elide: Text.ElideRight
                            Layout.fillWidth: true
 
                            Component.onCompleted: {
                                fc.applyOutline(this, Qt.rgba(0, 0, 0, 0.35))
                            }
                        }

                        Text {
                            id: bodyText
                            text: model.body
                            color: Qt.rgba(1, 1, 1, 0.5)
                            font.family: fc.mainFont
                            font.pixelSize: 15
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                 
                            Component.onCompleted: {
                                fc.applyOutline(this, Qt.rgba(0, 0, 0, 0.35))
                            }
                        }
                    }
                }
            }

            SequentialAnimation {
                id: addAnim
                PropertyAction { target: bannerCard; property: "opacity"; value: 0.0 }
                PropertyAction { target: bannerCard; property: "y"; value: 40 }
                ParallelAnimation {
                    NumberAnimation { target: bannerCard; property: "opacity"; to: 1.0; duration: 150 }
                    NumberAnimation { target: bannerCard; property: "y"; to: 0; duration: 200; easing.type: Easing.OutCubic }
                }
            }

            SequentialAnimation {
                id: removeAnim
                ParallelAnimation {
                    NumberAnimation { target: bannerCard; property: "opacity"; to: 0.0; duration: 150 }
                    NumberAnimation { target: bannerCard; property: "scale"; to: 0.9; duration: 150 }
                }
            }

            ListView.onAdd: addAnim.start()
            ListView.onRemove: removeAnim.start()
        }
    }
}
