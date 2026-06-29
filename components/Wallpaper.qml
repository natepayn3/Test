import QtQuick
import QtQuick.Layouts
import Qt.labs.folderlistmodel
import QtQuick.Shapes
import QtQuick.Effects
import QtMultimedia
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

PanelWindow {
    id: wallpaperWindow

    property bool active: false
    required property var rootShell

    property string currentWallpaperPath: rootShell && rootShell.wallpaperRef ? rootShell.wallpaperRef.currentWallpaperPath : ""
    property string currentScheme: "scheme-tonal-spot"

    signal applyFinished(string finalWallpaperPath)

    Timer {
        id: startupDelayTimer
        interval: 500
        running: false
        repeat: false
        onTriggered: {
            if (currentWallpaperPath && currentWallpaperPath !== "") {
                cacheCheckProc.running = true;
            }
        }
    }

    Process {
        id: cacheCheckProc
        running: false
        command: ["fish", "-c", "test -f '" + Quickshell.env("HOME") + "/.cache/matugen-previews.json'"]
        
        onExited: (exitCode) => {
            if (exitCode !== 0) {
                 wallpaperBackend.triggerBackendRun(currentWallpaperPath, false);
            }
        }
    }

    Component.onCompleted: {
        startupDelayTimer.start();
    }

    WlrLayershell.namespace: "quickshell-wallpaper"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: active ? WlrLayershell.OnDemand : WlrLayershell.None
    exclusionMode: ExclusionMode.Ignore
    
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    
    visible: active

    MouseArea {
        anchors.fill: parent
        onClicked: wallpaperWindow.active = false
    }

    FolderListModel {
        id: wallpaperModel
        folder: "file://" + Quickshell.env("HOME") + "/Pictures/Wallpapers"
        nameFilters: ["*.jpg", "*.png", "*.gif", "*.mp4", "*.webm"]
        showDirs: false
    }

    Process {
        id: wallpaperBackend
        running: false

        onExited: {
            wallpaperWindow.applyFinished(wallpaperWindow.currentWallpaperPath);
        }

        function triggerBackendRun(filePath, activeOnly) {
            if (!filePath || filePath === "") {
                filePath = carousel.currentFilePath || "";
                if (filePath === "") return;
            }

            let ext = filePath.split('.').pop().toLowerCase();
            let waylandDisplay = Quickshell.env("WAYLAND_DISPLAY") || "wayland-1";
            let sockPath = "/run/user/" + Quickshell.env("UID") + "/" + waylandDisplay + "-awww-daemon.sock";
            let script = "killall -q mpvpaper; ";
            script += "set TARGET_MON (hyprctl monitors -j | jq -r '.[] | select(.focused) | .name'); ";
            if (activeOnly) {
                if (ext === "mp4" || ext === "webm") {
                    script += "awww clear -o \"$TARGET_MON\" 2>/dev/null; pkill -f \"mpvpaper.*$TARGET_MON\"; mpvpaper -vs -o 'loop no-audio' \"$TARGET_MON\" '" + filePath + "'; ";
                } else {
                    script += "if not pgrep -x 'awww-daemon' > /dev/null; rm -f " + sockPath + "; nohup awww-daemon >/dev/null 2>&1 & disown; sleep 0.5; end; ";
                    script += "awww img -o \"$TARGET_MON\" '" + filePath + "' --transition-type wipe --transition-step 16 --transition-duration 1; ";
                }
            } else {
                if (ext === "mp4" || ext === "webm") {
                    script += "awww kill 2>/dev/null; killall -9 -q awww-daemon; rm -f " + sockPath + "; mpvpaper -vs -o 'loop no-audio' '*' '" + filePath + "'; ";
                } else {
                    script += "if not pgrep -x 'awww-daemon' > /dev/null; rm -f " + sockPath + "; nohup awww-daemon >/dev/null 2>&1 & disown; sleep 0.5; end; ";
                    script += "awww img '" + filePath + "' --transition-type wipe --transition-step 16 --transition-duration 1; ";
                }
            }

            let matugenTarget = (ext === "mp4" || ext === "webm") 
                ? (Quickshell.env("HOME") + "/.cache/quickshell_thumbs/" + filePath.split('/').pop() + ".jpg") 
                : filePath;
            let outPath = rootShell.matugenFilePath;
            
            script += "mkdir -p (dirname '" + outPath + "'); ";
            script += "matugen image '" + matugenTarget + "' -t " + wallpaperWindow.currentScheme + " --prefer=saturation --json hex > '" + outPath + ".tmp'; ";
            script += "mv '" + outPath + ".tmp' '" + outPath + "'; sync;";

            command = ["fish", "-c", script];
            running = false;
            running = true;
        }
    }

    function apply(filePath, activeOnly = false, customScheme = "") {
        if (filePath && filePath !== "") currentWallpaperPath = filePath;
        if (customScheme !== "") currentScheme = customScheme;
        
        if (!currentWallpaperPath || currentWallpaperPath === "") {
            currentWallpaperPath = carousel.currentFilePath;
        }

        wallpaperBackend.triggerBackendRun(currentWallpaperPath, activeOnly);
    }

    Item {
        id: carouselContainer
        width: parent.width
        
        // Dynamically scale height based on the total viewport constraints
        height: Math.min(parent.height * 0.55, 380)
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height - height - ((rootShell.barPosition === "bottom") ? 46 : 10)

        PathView {
            id: carousel
            anchors.centerIn: parent
            width: parent.width - (parent.width * 0.12)
            height: parent.height
            clip: false

            model: wallpaperModel
            focus: true
            interactive: true

            onOffsetChanged: {
                let minOffset = 0;
                let maxOffset = Math.max(0, modelCount - 1);
                if (offset < minOffset) offset = minOffset;
                else if (offset > maxOffset) offset = maxOffset;
            }

            property int modelCount: wallpaperModel.count
            
            // --- SCALED CONFIGURATION MATRIX ---
            // Replaces hardcoded layouts with proportional math fractions
            property real baseItemWidth: carousel.height * 0.52
            property real itemGap: -(baseItemWidth * 0.33)
            property real cardSkew: baseItemWidth * 0.3
            property real radiusVal: 10
            property real expandedWidth: baseItemWidth * 2.8
          
            property real itemSpacing: baseItemWidth + itemGap
            property int maxVisible: 14
            property int dynamicItemCount: Math.min(Math.max(1, modelCount), maxVisible)
            
            pathItemCount: dynamicItemCount
            property real currentPathLength: dynamicItemCount * itemSpacing

            preferredHighlightBegin: 0.5
            preferredHighlightEnd: 0.5
            highlightRangeMode: PathView.StrictlyEnforceRange
            highlightMoveDuration: 280

            path: Path {
                startX: carousel.width / 2 - carousel.currentPathLength / 2
                startY: carousel.height / 2
                PathLine { x: carousel.width / 2 + carousel.currentPathLength / 2; y: carousel.height / 2 }
            }

            property string currentFilePath: ""
            Keys.onReturnPressed: (event) => wallpaperWindow.apply(currentFilePath, event.modifiers & Qt.ControlModifier)
            Keys.onSpacePressed: (event) => wallpaperWindow.apply(currentFilePath, event.modifiers & Qt.ControlModifier)
            Keys.onEscapePressed: wallpaperWindow.active = false

            property bool isKeyboarding: false
            property real lastMouseX: 0
            property real lastMouseY: 0
            property int hoveredIndex: -1
            property int activeIndex: (!isKeyboarding && hoveredIndex !== -1) ? hoveredIndex : currentIndex

            HoverHandler {
                onPointChanged: {
                    let dx = Math.abs(point.position.x - carousel.lastMouseX);
                    let dy = Math.abs(point.position.y - carousel.lastMouseY);
                    if (dx > 2 || dy > 2) carousel.isKeyboarding = false;
                    carousel.lastMouseX = point.position.x;
                    carousel.lastMouseY = point.position.y;
                }
            }

            Keys.onLeftPressed: { carousel.isKeyboarding = true; carousel.hoveredIndex = -1; carousel.decrementCurrentIndex(); }
            Keys.onRightPressed: { carousel.isKeyboarding = true; carousel.hoveredIndex = -1; carousel.incrementCurrentIndex(); }

            delegate: Item {
                id: delegateRoot
                width: isActiveTarget ? carousel.expandedWidth : carousel.baseItemWidth
                height: carousel.height * 0.85
                
                Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                
                property bool isFocused: PathView.isCurrentItem
                property bool isActiveTarget: carousel.activeIndex === index

                onIsFocusedChanged: if (isFocused) carousel.currentFilePath = filePath;
                Component.onCompleted: if (isFocused) carousel.currentFilePath = filePath;
                
                property real diff: {
                    if (carousel.modelCount === 0) return 0;
                    let d = (index - carousel.activeIndex) % carousel.modelCount;
                    if (d > carousel.modelCount / 2) d -= carousel.modelCount;
                    else if (d < -carousel.modelCount / 2) d += carousel.modelCount;
                    return d;
                }

                z: isActiveTarget ? 1000 : 500 - Math.abs(diff)

                property real pushAmount: (carousel.expandedWidth - carousel.baseItemWidth) / 2
                property real targetXShift: {
                    if (isActiveTarget || carousel.activeIndex === -1) return 0;
                    if (Math.abs(diff) > carousel.maxVisible / 2) return 0;
                    return diff < 0 ? -pushAmount : pushAmount;
                }

                Behavior on targetXShift { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

                transform: Translate {
                    x: delegateRoot.targetXShift
                }

                property string pathStr: String(filePath).toLowerCase()
                property bool isVideo: pathStr.endsWith(".mp4") || pathStr.endsWith(".webm")
                property string fileName: String(filePath).split('/').pop()
                property string thumbDir: Quickshell.env("HOME") + "/.cache/quickshell_thumbs"
                property string thumbFile: thumbDir + "/" + fileName + ".jpg"
                property string thumbUrl: "file://" + thumbFile
                property bool thumbReady: false
                
                Process {
                    running: delegateRoot.isVideo && delegateRoot.isActiveTarget
                    command: ["fish", "-c", "mkdir -p '" + thumbDir + "'; if not test -f '" + thumbFile + "'; ffmpeg -y -i '" + filePath + "' -ss 00:00:00.100 -vframes 1 -vf 'scale=450:-1' -q:v 2 '" + thumbFile + "' >/dev/null 2>&1; end"]
                    onExited: delegateRoot.thumbReady = true
                }

                Item {
                    id: visualContainer
                    anchors.fill: parent
                    
                    scale: delegateRoot.isActiveTarget ? 1.0 : 0.95
                    Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: carousel.isKeyboarding ? Qt.BlankCursor : Qt.PointingHandCursor
                        onEntered: if (!carousel.isKeyboarding) carousel.hoveredIndex = index;
                        onExited: if (carousel.hoveredIndex === index) carousel.hoveredIndex = -1;
                        onClicked: (mouse) => {
                            wallpaperWindow.apply(filePath, mouse.modifiers & Qt.ControlModifier);
                            mouse.accepted = true;
                        }
                    }

                    Shape {
                        id: skewMaskShape
                        anchors.fill: parent
                        visible: false
                        layer.enabled: true
                        layer.smooth: true
                        antialiasing: true
                        preferredRendererType: Shape.CurveRenderer
                        
                        property real r: carousel.radiusVal
                        property real sk: carousel.cardSkew
                        
                        ShapePath {
                            fillColor: "white"
                            strokeColor: "transparent"
                            startX: skewMaskShape.sk + skewMaskShape.r; startY: 0
                            PathLine { x: skewMaskShape.width - skewMaskShape.r; y: 0 }
                            PathQuad { x: skewMaskShape.width; y: skewMaskShape.r; controlX: skewMaskShape.width; controlY: 0 }
                            PathLine { x: skewMaskShape.width - skewMaskShape.sk; y: skewMaskShape.height - skewMaskShape.r }
                            PathQuad { x: skewMaskShape.width - skewMaskShape.sk - skewMaskShape.r; y: skewMaskShape.height; controlX: skewMaskShape.width - skewMaskShape.sk; controlY: skewMaskShape.height }
                            PathLine { x: skewMaskShape.r; y: skewMaskShape.height }
                            PathQuad { x: 0; y: skewMaskShape.height - skewMaskShape.r; controlX: 0; controlY: skewMaskShape.height }
                            PathLine { x: skewMaskShape.sk; y: skewMaskShape.r }
                            PathQuad { x: skewMaskShape.sk + skewMaskShape.r; y: 0; controlX: skewMaskShape.sk; controlY: 0 }
                        }
                    }

                    Image {
                        id: bgImg
                        anchors.fill: parent
                        source: delegateRoot.isVideo ? (delegateRoot.thumbReady ? delegateRoot.thumbUrl : "") : fileUrl
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: true
                        visible: false
                        
                        // Fixed: Bind to the stable max width/height to prevent mid-animation cache evictions
                        sourceSize: Qt.size(Math.floor(carousel.expandedWidth * 1.2), Math.floor(carousel.height * 1.2))
                    }

                    Loader {
                        id: vidLoader
                        anchors.fill: parent
                        active: delegateRoot.isVideo && delegateRoot.isActiveTarget
                        visible: false
                        sourceComponent: Component {
                            Video {
                                anchors.fill: parent
                                source: fileUrl
                                fillMode: VideoOutput.PreserveAspectCrop
                                loops: MediaPlayer.Infinite
                                muted: true
                                Component.onCompleted: play()
                            }
                        }
                    }

                    MultiEffect {
                        anchors.fill: parent
                        source: vidLoader.active ? vidLoader.item : bgImg
                        maskEnabled: true
                        maskSource: skewMaskShape
                        maskThresholdMin: 0.5
                        maskSpreadAtMin: 1.0
                    }

                    Loader {
                        anchors.fill: parent
                        active: delegateRoot.isActiveTarget
                        z: 5
                        sourceComponent: Component {
                            Item {
                                anchors.fill: parent
                                Shape {
                                    id: glowOutline
                                    anchors.fill: parent
                                    antialiasing: true
                                    
                                    property real r: carousel.radiusVal
                                    property real sk: carousel.cardSkew
                                    
                                    ShapePath {
                                        fillColor: "transparent"
                                        strokeColor: rootShell.primaryColor ? Qt.color(rootShell.primaryColor) : "#ffffff"
                                        strokeWidth: 3
                                        
                                        startX: glowOutline.sk + glowOutline.r; startY: 0
                                        PathLine { x: glowOutline.width - glowOutline.r; y: 0 }
                                        PathQuad { x: glowOutline.width; y: glowOutline.r; controlX: glowOutline.width; controlY: 0 }
                                        PathLine { x: glowOutline.width - glowOutline.sk; y: glowOutline.height - glowOutline.r }
                                        PathQuad { x: glowOutline.width - glowOutline.sk - glowOutline.r; y: glowOutline.height; controlX: glowOutline.width - glowOutline.sk; controlY: glowOutline.height }
                                        PathLine { x: glowOutline.r; y: glowOutline.height }
                                        PathQuad { x: 0; y: glowOutline.height - glowOutline.r; controlX: 0; controlY: glowOutline.height }
                                        PathLine { x: glowOutline.sk; y: glowOutline.r }
                                        PathQuad { x: glowOutline.sk + glowOutline.r; y: 0; controlX: glowOutline.sk; controlY: 0 }
                                    }
                                }
                                MultiEffect {
                                    anchors.fill: parent
                                    source: glowOutline
                                    shadowEnabled: true
                                    shadowColor: rootShell.primaryColor ? Qt.color(rootShell.primaryColor) : "#ffffff"
                                    shadowBlur: 0
                                    shadowVerticalOffset: 0
                                    shadowHorizontalOffset: 0
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}