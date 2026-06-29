import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Io

Scope {
    id: launcherModuleRoot

    property alias launcherWindowObject: launcherWindow

    FontConfig { id: fonts }

    // --- REALIGNED SYSTEM THEME MATRIX ---
    // Swapped out the 90% heavy dark block for the same universal neutral tone used in your docks
    property color themeBackground: Qt.rgba(0.4, 0.4, 0.4, 0.7) 
    property color themeText: "#ffffff"
    property color themeAccent: Qt.rgba(0.4, 0.4, 0.4, 0.28) 
    property color themeBorder: Qt.rgba(0, 0, 0, 0.15)
    property color cardBorder: Qt.rgba(0, 0, 0, 0.2)
    
    property bool active: false
  
    onActiveChanged: {
        if (active) {
            launcherWindow.visible = true;
        }
    }

    signal closeRequested()
    onCloseRequested: launcherModuleRoot.active = false

    PanelWindow {
        id: launcherWindow
        visible: false
        WlrLayershell.namespace: "quickshell-launcher"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrLayershell.OnDemand
        exclusionMode: ExclusionMode.Ignore 

        anchors { left: true; right: true; top: true; bottom: true } 
        color: "transparent"

        property var allApps: []
        property var filteredApps: []
        property var localPins: []

        FileView {
            id: pinCacheReader
            path: Quickshell.env("HOME") + "/.cache/quickshell_launcher_pins.json" 
            onTextChanged: {
                let cleanText = text().trim();
                if (!cleanText || cleanText === "[]") return; 
                try {
                    let parsed = JSON.parse(cleanText);
                    if (parsed && parsed.pins) { 
                        launcherWindow.localPins = parsed.pins;
                        launcherWindow.updateModel(); 
                    }
                } catch(e) {}
            }
        }

        function togglePin(appPath) {
            let currentPins = launcherWindow.localPins.slice();
            let idx = currentPins.indexOf(appPath); 
            if (idx !== -1) {
                currentPins.splice(idx, 1);
            } else { 
                currentPins.push(appPath);
            } 
            launcherWindow.localPins = currentPins;
            launcherWindow.updateModel();
            let jsonStr = JSON.stringify({ "pins": currentPins }); 
            Quickshell.execDetached(["fish", "-c", "echo '" + jsonStr + "' > ~/.cache/quickshell_launcher_pins.json"]);
        } 

        Process {
            id: appFetcher
            command: ["bash", "-c", "find /usr/share/applications ~/.local/share/applications -maxdepth 2 -name '*.desktop' 2>/dev/null | awk 'BEGIN { print \"[\"; c=0 } { name=\"\"; exec=\"\"; icon=\"\"; desc=\"\"; nshow=0; while ((getline line < $0) > 0) { if (line ~ /^Name=/ && name==\"\") name = substr(line, 6); if (line ~ /^Exec=/ && exec==\"\") exec = substr(line, 6); if (line ~ /^Icon=/ && icon==\"\") icon = substr(line, 6); if (line ~ /^Comment=/ && desc==\"\") desc = substr(line, 9); if (line ~ /^NoDisplay=true/) nshow=1 } close($0); if (name != \"\" && exec != \"\" && nshow==0) { gsub(/[\"\\\\]/, \"\", name); gsub(/[\"\\\\]/, \"\", exec); gsub(/[\"\\\\]/, \"\", icon); gsub(/[\"\\\\]/, \"\", desc); if (c > 0) print \",\"; printf \"{\\\"name\\\":\\\"%s\\\", \\\"exec\\\":\\\"%s\\\", \\\"icon\\\":\\\"%s\\\", \\\"desc\\\":\\\"%s\\\", \\\"path\\\":\\\"%s\\\"}\", name, exec, icon, desc, $0; c++ } } END { print \"]\" }'"] 
            running: false
            stdout: StdioCollector {
                onStreamFinished: {
                    try {
                        launcherWindow.allApps = JSON.parse(this.text);
                        launcherWindow.updateModel(); 
                    } catch(e) {}
                }
            }
        }

        function updateModel() {
            let query = searchInput.text.trim().toLowerCase();
            let pins = []; 
            let others = [];

            for (let i = 0; i < launcherWindow.allApps.length; i++) {
                let app = launcherWindow.allApps[i];
                if (query !== "" && !app.name.toLowerCase().includes(query) && !app.desc.toLowerCase().includes(query)) continue; 
                if (launcherWindow.localPins.includes(app.path)) {
                    pins.push(app);
                } else { 
                    others.push(app);
                } 
            }

            pins.sort((a,b) => a.name.localeCompare(b.name));
            others.sort((a,b) => a.name.localeCompare(b.name)); 
            launcherWindow.filteredApps = pins.concat(others);
            
            appListView.currentIndex = 0;
            appListView.positionViewAtBeginning();
        } 

        function launchApp(execString) {
            let cleanExec = execString.replace(/%[uUfFkKcCiI]/g, "").trim();
            Hyprland.dispatch(`hl.dsp.exec_cmd("${cleanExec}")`);
            launcherModuleRoot.closeRequested();
        }

        onVisibleChanged: {
            if (visible) {
                if (allApps.length === 0) appFetcher.running = true;
                searchInput.text = ""; 
                searchInput.forceActiveFocus();
                pinCacheReader.reload();
                updateModel();
            }
        }

        MouseArea {
            anchors.fill: parent
            propagateComposedEvents: true
            onPressed: (mouse) => {
                launcherModuleRoot.closeRequested();
                mouse.accepted = false;  
            }
        }

        Item {
            id: launcherCardFrame
            width: 500  
            height: 500 
            anchors.centerIn: parent
            transformOrigin: Item.Center 

            MouseArea {
                anchors.fill: parent
                onPressed: (event) => event.accepted = true
                onClicked: (event) => event.accepted = true
            }

            states: [
                State { 
                    name: "hidden"
                    when: !launcherModuleRoot.active
                    PropertyChanges { target: launcherCardFrame; opacity: 0.0; scale: 0.3 } 
                },
                State {
                    name: "shown"
                    when: launcherModuleRoot.active
                    PropertyChanges { target: launcherCardFrame; opacity: 1.0; scale: 1.0 } 
                }
            ]

            transitions: [
                Transition {
                    from: "hidden"
                    to: "shown" 
                    ParallelAnimation {
                        NumberAnimation { 
                            target: launcherCardFrame;
                            property: "scale"; 
                            duration: 400; 
                            easing.type: Easing.OutBack;
                            easing.amplitude: 2.5 
                        } 
                        NumberAnimation { target: launcherCardFrame; property: "opacity"; duration: 200; easing.type: Easing.OutQuad } 
                    }
                },
                Transition {
                    from: "shown"
                    to: "hidden" 
                    SequentialAnimation {
                        ParallelAnimation {
                            NumberAnimation { target: launcherCardFrame; property: "scale"; duration: 200; easing.type: Easing.InBack; easing.amplitude: 1.5 } 
                            NumberAnimation { target: launcherCardFrame; property: "opacity"; duration: 150; easing.type: Easing.InQuad } 
                        }
                        ScriptAction { script: launcherWindow.visible = false } 
                    }
                }
            ]

            // --- VISUAL LAYER SYSTEM ---
            // Removed border and antialiasing from the source plane to avoid shadow mask bleeding
            Rectangle {
                id: cardMainBody 
                anchors.fill: parent
                color: launcherModuleRoot.themeBackground
                radius: 16 
                visible: false 
            }

            // Universal hardware shadow overlay engine
            MultiEffect {
                id: cardShadow
                anchors.fill: cardMainBody
                source: cardMainBody
                shadowEnabled: true
                shadowColor: Qt.rgba(0, 0, 0, 0.35)
                shadowBlur: 0
                shadowVerticalOffset: 0
                shadowHorizontalOffset: 0
            }

            // Independent border overlay rendered safely above the shadow plane
            Rectangle {
                id: cardBorderOverlay
                anchors.fill: parent
                color: "transparent"
                border.color: launcherModuleRoot.cardBorder
                border.width: 1
                radius: 16
                antialiasing: true
            }

            Rectangle {
                id: layoutContentWrapper 
                anchors.fill: parent
                color: "transparent"
                radius: 16
                clip: true

                Item {
                    anchors.fill: parent
                    anchors.margins: 20 

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 12 

                        TextField {
                            id: searchInput
                            Layout.fillWidth: true 
                            Layout.preferredHeight: 46 
                            placeholderText: "Search apps..."
                            
                            font.family: fonts.mainFont
                            font.pixelSize: 20 
                            renderType: fonts.preferredRenderType
                            antialiasing: fonts.useAntialiasing
                            
                            color: launcherModuleRoot.themeText
                            placeholderTextColor: Qt.rgba(1, 1, 1, 0.3)
                            selectByMouse: true
                            verticalAlignment: TextInput.AlignVCenter 
                            
                            background: Rectangle { 
                                color: Qt.rgba(0, 0, 0, 0.15) // Down-tints input matrix box cleanly
                                border.color: searchInput.activeFocus ? launcherModuleRoot.themeAccent : launcherModuleRoot.themeBorder 
                                border.width: 1
                                radius: 10 
                            }

                            onTextChanged: launcherWindow.updateModel() 

                            Keys.onPressed: (event) => {
                                if (event.key === Qt.Key_Down) {
                                    appListView.incrementCurrentIndex(); 
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Up) {
                                    appListView.decrementCurrentIndex();
                                    event.accepted = true; 
                                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                    if (appListView.currentItem) {
                                        launcherWindow.launchApp(appListView.currentItem.appExec);
                                    } 
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Escape) { 
                                    launcherModuleRoot.closeRequested();
                                    event.accepted = true; 
                                }
                            }
                        }

                        ScrollView {
                            Layout.fillWidth: true
                            Layout.fillHeight: true 
                            clip: true

                            ListView {
                                id: appListView
                                spacing: 4 
                                keyNavigationEnabled: false
                                model: launcherWindow.filteredApps 
                                
                                delegate: ItemDelegate {
                                    id: appDelegate
                                    width: appListView.width 
                                    height: 56 
                                    highlighted: appListView.currentIndex === index 
                                    
                                    property string appExec: modelData.exec
                                    property bool isPinned: launcherWindow.localPins.includes(modelData.path)

                                    background: Rectangle { 
                                        // Matched completely to dock module background design structures
                                        color: appDelegate.highlighted
                                            ? launcherModuleRoot.themeAccent 
                                            : (appDelegate.hovered ? Qt.rgba(1, 1, 1, 0.05) : "transparent")
                                        border.color: appDelegate.highlighted ? launcherModuleRoot.cardBorder : "transparent"
                                        border.width: 1
                                        radius: 10 
                                    } 

                                    contentItem: RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: 10 
                                        spacing: 12

                                        Image { 
                                            Layout.preferredWidth: 28 
                                            Layout.preferredHeight: 28
                                            sourceSize.width: 56 
                                            sourceSize.height: 56
                                            source: Quickshell.iconPath(modelData.icon !== "" ? modelData.icon : "application-x-executable") 
                                            fillMode: Image.PreserveAspectFit
                                            asynchronous: true
                                        } 

                                        ColumnLayout {
                                            Layout.fillWidth: true 
                                            spacing: 1
                                            Layout.alignment: Qt.AlignVCenter 

                                            Text { 
                                                text: modelData.name
                                                font.family: fonts.mainFont 
                                                font.pixelSize: 16
                                                style: Text.Outline
                                                styleColor: Qt.rgba(0, 0, 0, 0.45) // Outline shield locks readable contrast over pure white apps
                                                color: launcherModuleRoot.themeText 
                                                font.weight: appDelegate.isPinned ? Font.Bold : Font.Normal 
                                                Layout.fillWidth: true
                                                elide: Text.ElideRight
                                                renderType: fonts.preferredRenderType 
                                                antialiasing: fonts.useAntialiasing 
                                            }

                                            Text {
                                                text: modelData.desc !== "" ? modelData.desc : "Application" 
                                                font.family: fonts.mainFont
                                                font.pixelSize: 14
                                                style: Text.Outline
                                                styleColor: Qt.rgba(0, 0, 0, 0.3)
                                                color: Qt.rgba(1, 1, 1, 0.5) 
                                                Layout.fillWidth: true
                                                elide: Text.ElideRight 
                                                renderType: fonts.preferredRenderType
                                                antialiasing: fonts.useAntialiasing 
                                            }
                                        }

                                        Item {
                                            Layout.fillWidth: true
                                        }

                                        Text {
                                            text: "keep" 
                                            font.family: fonts.iconFont
                                            font.pixelSize: 18
                                            style: Text.Outline
                                            styleColor: Qt.rgba(0, 0, 0, 0.4)
                                            color: launcherModuleRoot.themeText
                                            visible: appDelegate.isPinned 
                                            Layout.alignment: Qt.AlignVCenter
                                            Layout.rightMargin: 4
                                            renderType: fonts.preferredRenderType
                                            antialiasing: fonts.useAntialiasing
                                        }
                                    } 

                                    MouseArea {
                                        anchors.fill: parent 
                                        acceptedButtons: Qt.LeftButton | Qt.RightButton 
                                        cursorShape: Qt.PointingHandCursor
                                        hoverEnabled: true

                                        property int lastScreenX: -1 
                                        property int lastScreenY: -1

                                        onPositionChanged: (mouse) => { 
                                            let currentX = Math.floor(mouse.screenX);
                                            let currentY = Math.floor(mouse.screenY);

                                            let deltaX = Math.abs(currentX - lastScreenX); 
                                            let deltaY = Math.abs(currentY - lastScreenY);
                                            if (lastScreenX !== -1 && (deltaX > 2 || deltaY > 2)) {
                                                if (appListView.currentIndex !== index) { 
                                                    appListView.currentIndex = index;
                                                }
                                            }
                                            
                                            lastScreenX = currentX;
                                            lastScreenY = currentY; 
                                        }

                                        onExited: {
                                            lastScreenX = -1;
                                            lastScreenY = -1; 
                                        }

                                        onClicked: (mouse) => {
                                            if (mouse.button === Qt.RightButton) {
                                                launcherWindow.togglePin(modelData.path);
                                            } else { 
                                                launcherWindow.launchApp(modelData.exec);
                                            }
                                        }
                                    }
                                }
                            } 
                        }
                    }
                }
            }
        }
    }
}