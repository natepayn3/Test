import QtQuick
import QtQuick.Layouts

Rectangle {
    id: mediaRoot
    color: Qt.rgba(0, 0, 0, 0.15)
    radius: 12
    clip: true

    // Dynamically calculate the card bounds based on internal content + margins
    implicitWidth: internalGrid.implicitWidth + 32
    implicitHeight: internalGrid.implicitHeight + 16

    signal playPauseClicked()
    signal prevClicked()
    signal nextClicked()

    GridLayout {
        id: internalGrid // Tagged for the implicit dimension bindings
        anchors.fill: parent
        anchors.margins: 16
        
        columns: dashboardRoot.isHorizontal ? 1 : 2
        rowSpacing: 16
        columnSpacing: 16

        // Layer 1: Art & Title
        RowLayout {
            Layout.fillWidth: true
            Layout.alignment: dashboardRoot.isHorizontal ? Qt.AlignHCenter : Qt.AlignLeft
            spacing: 16

            Rectangle { 
                width: 48; height: 48; radius: 8
                color: Qt.rgba(rootShell.colorText.r, rootShell.colorText.g, rootShell.colorText.b, 0.2)
                clip: true 

                Image {
                    anchors.fill: parent
                    source: dashboardRoot.mediaArtUrl
                    fillMode: Image.PreserveAspectCrop
                    visible: dashboardRoot.mediaArtUrl !== ""
                    asynchronous: true
                }

                Text { 
                    anchors.centerIn: parent
                    text: "music_note"
                    font.family: "Material Symbols Outlined"
                    color: rootShell.colorText
                    font.pixelSize: 24 
                    visible: dashboardRoot.mediaArtUrl === ""
                } 
            }

            ColumnLayout {
                spacing: 4
                Layout.maximumWidth: dashboardRoot.isHorizontal ? 160 : 220 
                
                // 🎯 Hides the text when stopped, allowing the art box to perfectly center itself
                visible: dashboardRoot.mediaTitle !== "Not Playing"
                
                Text { text: dashboardRoot.mediaTitle; color: rootShell.colorText; font.family: rootShell.shellFont; font.bold: true; font.pixelSize: 14; elide: Text.ElideRight; Layout.fillWidth: true }
                Text { text: dashboardRoot.mediaArtist; color: rootShell.colorSubtext; font.family: rootShell.shellFont; font.pixelSize: 12; elide: Text.ElideRight; Layout.fillWidth: true }
            }
        }

        // Layer 2: Playback Controls
        RowLayout {
            Layout.fillWidth: true
            // Center the controls when stacked, push them to the right when inline
            Layout.alignment: dashboardRoot.isHorizontal ? Qt.AlignHCenter : Qt.AlignRight
            spacing: 4

            MouseArea { 
                width: 32; height: 32; cursorShape: Qt.PointingHandCursor
                onClicked: mediaRoot.prevClicked()
                Text { anchors.centerIn: parent; text: "skip_previous"; font.family: "Material Symbols Outlined"; color: rootShell.colorText; font.pixelSize: 24 }
            }
            
            Rectangle { 
                width: 42; height: 42; radius: 21; color: rootShell.colorText
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: mediaRoot.playPauseClicked() }
                Text { anchors.centerIn: parent; text: dashboardRoot.mediaStatus === "Playing" ? "pause" : "play_arrow"; font.family: "Material Symbols Outlined"; color: rootShell.colorBackground; font.pixelSize: 24 } 
            }
            
            MouseArea { 
                width: 32; height: 32; cursorShape: Qt.PointingHandCursor
                onClicked: mediaRoot.nextClicked()
                Text { anchors.centerIn: parent; text: "skip_next"; font.family: "Material Symbols Outlined"; color: rootShell.colorText; font.pixelSize: 24 }
            }
        }
        
        // Pushes the content upward to prevent weird floating behavior
        Item { 
            Layout.fillHeight: true
            Layout.columnSpan: dashboardRoot.isHorizontal ? 1 : 2
        } 
    }
}
