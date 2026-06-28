import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import Quickshell.Services.Notifications
import "./components"

Item {
    id: dashboardRoot
    anchors.fill: parent

    // --- Live Tracking Data Processors ---
    readonly property bool isParentOpen: popupWindow.isOpen
    property real sysCpu: 0.0
    property real sysRam: 0.0
    property real sysGpu: 0.0
    property real sysDisk: 0.0
    property var lastCpuTotal: 0
    property var lastCpuIdle: 0

    property real currentVolume: 0.0
    property bool wifiAvailable: false
    property bool wifiActive: false
    property bool btActive: false
    property bool dndActive: false
    property bool caffeineActive: false

    property string mediaTitle: "Not Playing"
    property string mediaArtist: "---"
    property string mediaStatus: "Stopped"
    property string mediaArtUrl: ""

    // --- Weather Cache ---
    property string weatherLocationOverride: ""
    property string weatherTemp: "--"
    property string weatherDesc: "Loading..."
    property string weatherGlyph: "cloud"

    readonly property var weatherIconMap: {
        "0": "clear_day", "1": "partly_cloudy_day", "2": "partly_cloudy_day", "3": "cloudy",
        "45": "foggy", "48": "foggy", "51": "rainy", "53": "rainy", "55": "rainy", "61": "rainy",
        "63": "rainy", "65": "rainy", "71": "snowing", "73": "snowing", "75": "snowing",
        "77": "snowing", "80": "rainy", "81": "rainy", "82": "rainy", "85": "snowing",
        "86": "snowing", "95": "thunderstorm", "96": "thunderstorm", "99": "thunderstorm"
    }
    readonly property var weatherDescMap: {
        "0": "Clear Sky", "1": "Mainly Clear", "2": "Partly Cloudy", "3": "Overcast",
        "45": "Foggy", "48": "Rime Fog", "51": "Light Drizzle", "53": "Moderate Drizzle",
        "55": "Dense Drizzle", "61": "Slight Rain", "63": "Moderate Rain", "65": "Heavy Rain",
        "71": "Light Snow", "73": "Moderate Snow", "75": "Heavy Snow", "77": "Snow Grains",
        "80": "Light Showers", "81": "Moderate Showers", "82": "Heavy Showers",
        "85": "Light Snow Showers", "86": "Heavy Snow Showers", "95": "Thunderstorm",
        "96": "Storm w/ Hail", "99": "Severe Storm"
    }

    // --- Activation Engine Loops ---
    onIsParentOpenChanged: {
        if (isParentOpen) {
            sysStatsTimer.running = true;
            cpuStatReader.reload();
            memInfoReader.reload();
            diskGpuProc.running = true;
            volFetcher.running = true;
            wifiStateCheck.running = true;
            btStateCheck.running = true;
            checkHypridleProc.running = true;
            if (weatherTemp === "--") weatherFetcher.running = true;
        } else {
            sysStatsTimer.running = false;
        }
    }

    Component.onCompleted: {
        mediaFollower.running = true;
        volumeEventListener.running = true;
        wifiStateCheck.running = true;
        btStateCheck.running = true;
        checkHypridleProc.running = true;
    }

    NotificationServer {
        id: notifServer
        bodySupported: true; actionsSupported: true; imageSupported: true; persistenceSupported: true
        onNotification: (notif) => { if (!dashboardRoot.dndActive) notif.tracked = true; else notif.dismiss(); }
    }

    Timer { id: weatherTimer; interval: 900000; running: true; repeat: true; triggeredOnStart: true; onTriggered: weatherFetcher.running = true }
    Timer { id: sysStatsTimer; interval: 4000; running: false; repeat: true; onTriggered: { cpuStatReader.reload(); memInfoReader.reload(); diskGpuProc.running = true; } }

    FileView {
        id: memInfoReader; path: "/proc/meminfo"
        onTextChanged: {
            let lines = text().split('\n'); let total = 0, avail = 0;
            for (let i = 0; i < lines.length; i++) {
                if (lines[i].startsWith("MemTotal:")) total = parseInt(lines[i].replace(/\D/g, ''));
                if (lines[i].startsWith("MemAvailable:")) avail = parseInt(lines[i].replace(/\D/g, ''));
                if (total && avail) break;
            }
            if (total > 0) dashboardRoot.sysRam = (total - avail) / total;
        }
    }

    FileView {
        id: cpuStatReader; path: "/proc/stat"
        onTextChanged: {
            let cpuLine = text().split('\n')[0]; let parts = cpuLine.split(/\s+/).filter(Boolean);
            if (parts.length >= 5) {
                let user = parseInt(parts[1]) || 0; let nice = parseInt(parts[2]) || 0; let system = parseInt(parts[3]) || 0; let idle = parseInt(parts[4]) || 0;
                let iowait = parseInt(parts[5]) || 0; let irq = parseInt(parts[6]) || 0; let softirq = parseInt(parts[7]) || 0;
                let total = user + nice + system + idle + iowait + irq + softirq;
                let totalDelta = total - dashboardRoot.lastCpuTotal; let idleDelta = idle - dashboardRoot.lastCpuIdle;
                if (totalDelta > 0) dashboardRoot.sysCpu = (totalDelta - idleDelta) / totalDelta;
                dashboardRoot.lastCpuTotal = total; dashboardRoot.lastCpuIdle = idle;
            }
        }
    }

    Process {
        id: diskGpuProc
        command: ["sh", "-c", "cat /sys/class/drm/card0/device/gpu_busy_percent 2>/dev/null || cat /sys/class/hwmon/hwmon*/device/gpu_busy_percent 2>/dev/null || nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null || echo 0; df / | awk 'NR==2 {print $5}' | sed 's/%//'"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let lines = this.text.trim().split("\n");
                    if (lines.length >= 2) {
                        let rawGpu = parseFloat(lines[0]) || 0.0;
                        dashboardRoot.sysGpu = rawGpu > 1.0 ? rawGpu / 100.0 : rawGpu;
                        dashboardRoot.sysDisk = (parseFloat(lines[1]) || 0.0) / 100.0;
                    }
                } catch(e) {}
                diskGpuProc.running = false;
            }
        }
    }

    Process {
        id: weatherFetcher; command: ["curl", "-s", "https://wttr.is/" + dashboardRoot.weatherLocationOverride.trim() + "?format=j1"]; running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let data = JSON.parse(this.text); let current = data.current_condition[0];
                    dashboardRoot.weatherTemp = current.temp_F + "°F";
                    let code = current.weatherCode.toString();
                    dashboardRoot.weatherDesc = dashboardRoot.weatherDescMap[code] !== undefined ? dashboardRoot.weatherDescMap[code] : current.weatherDesc[0].value;
                    dashboardRoot.weatherGlyph = dashboardRoot.weatherIconMap[code] !== undefined ? dashboardRoot.weatherIconMap[code] : "cloud";
                } catch (e) {}
                weatherFetcher.running = false;
            }
        }
    }

    Process { id: volumeEventListener; command: ["sh", "-c", "pactl subscribe | grep --line-buffered \"sink\""]; running: false; stdout: SplitParser { onRead: (data) => volFetcher.running = true } }
    Process {
        id: volFetcher; command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]; running: false
        stdout: StdioCollector { onStreamFinished: { let parts = this.text.trim().split(" "); if (parts.length >= 2 && !volSlider.isPressed) dashboardRoot.currentVolume = parseFloat(parts[1]); volFetcher.running = false; } }
    }

    Process {
        id: mediaFollower; command: ["playerctl", "metadata", "--follow", "--format", "{\"title\": \"{{title}}\", \"artist\": \"{{artist}}\", \"status\": \"{{status}}\", \"artUrl\": \"{{mpris:artUrl}}\"}"]; running: false
        stdout: SplitParser {
            onRead: (data) => {
                try {
                    let parsed = JSON.parse(data.trim());
                    if (parsed.status === "Stopped") {
                        dashboardRoot.mediaTitle = "Not Playing"; dashboardRoot.mediaArtist = "---"; dashboardRoot.mediaStatus = "Stopped"; dashboardRoot.mediaArtUrl = "";
                    } else {
                        dashboardRoot.mediaTitle = parsed.title || "Unknown"; dashboardRoot.mediaArtist = parsed.artist || "Unknown"; dashboardRoot.mediaStatus = parsed.status || "Stopped"; dashboardRoot.mediaArtUrl = parsed.artUrl || "";
                    }
                } catch(e) {
                    dashboardRoot.mediaTitle = "Not Playing"; dashboardRoot.mediaArtist = "---"; dashboardRoot.mediaStatus = "Stopped"; dashboardRoot.mediaArtUrl = "";
                }
            }
        }
    }

    Process {
        id: wifiStateCheck; command: ["sh", "-c", "nmcli -t -f TYPE,STATE device | grep -q '^wifi:' && echo 'AVAILABLE' || echo 'MISSING'; nmcli radio wifi"]; running: false
        stdout: StdioCollector {
            onStreamFinished: {
                let lines = this.text.trim().split("\n");
                if (lines.length >= 1) dashboardRoot.wifiAvailable = (lines[0] === "AVAILABLE");
                if (lines.length >= 2) dashboardRoot.wifiActive = dashboardRoot.wifiAvailable && (lines[1].trim() === "enabled");
                wifiStateCheck.running = false;
            }
        }
    }

    Process {
        id: btStateCheck; command: ["sh", "-c", "bluetoothctl show | grep -q 'Powered: yes' && echo 'ON' || echo 'OFF'"]; running: false
        stdout: StdioCollector { onStreamFinished: { dashboardRoot.btActive = (this.text.trim() === "ON"); btStateCheck.running = false; } }
    }

    Process {
        id: checkHypridleProc; command: ["pgrep", "-x", "hypridle"]; running: false
        stdout: StdioCollector { onStreamFinished: { dashboardRoot.caffeineActive = (this.text.trim() === ""); checkHypridleProc.running = false; } }
    }

    Process { id: setVolProc; running: false }
    Process { id: wifiToggleProc; running: false }
    Process { id: btToggleProc; running: false }
    Process { id: caffeineToggleProc; running: false }
    Process { id: actionCmdProc; running: false }

    // --- Base View Area Canvas ---
    Rectangle {
        id: dashboardCard
        anchors.centerIn: parent
        width: parent.width - 30
        height: parent.height - 30
        color: "#2d2d34" 
        radius: 12
        border.width: 0

        layer.enabled: true
        layer.smooth: true
        layer.samples: 4

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 12

            // BLOCK 1: Centered Clock Header Layout (Side-by-Side Format)
            RowLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter // 🎯 Centers the entire row block

                // Center-balanced spacer setup
                Item { Layout.fillWidth: true }

                RowLayout {
                    spacing: 16
                    
                    // Large Clock Text
                    Text {
                        id: clockTimeLabel
                        text: (typeof rootShell !== "undefined" && rootShell.clockRef && rootShell.clockRef.currentTime) ? 
                              rootShell.clockRef.currentTime.toLocaleTimeString(Qt.locale(), "h:mm AP") : "9:24 PM"
                        font.family: typeof rootShell !== "undefined" ? rootShell.shellFont : "Sans"
                        font.pixelSize: 32
                        font.bold: true
                        color: typeof rootShell !== "undefined" ? rootShell.colorText : "#f5f5f5"
                    }

                    // Stacked Day & Date directly next to it
                    ColumnLayout {
                        spacing: 2
                        Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                        
                        Text {
                            text: (typeof rootShell !== "undefined" && rootShell.clockRef && rootShell.clockRef.currentTime) ? 
                                  rootShell.clockRef.currentTime.toLocaleDateString(Qt.locale(), "dddd") : "Saturday"
                            font.family: typeof rootShell !== "undefined" ? rootShell.shellFont : "Sans"
                            font.pixelSize: 16
                            font.bold: true
                            color: typeof rootShell !== "undefined" ? rootShell.colorText : "#f5f5f5"
                        }
                        Text {
                            text: (typeof rootShell !== "undefined" && rootShell.clockRef && rootShell.clockRef.currentTime) ? 
                                  rootShell.clockRef.currentTime.toLocaleDateString(Qt.locale(), "MMMM d") : "June 27"
                            font.family: typeof rootShell !== "undefined" ? rootShell.shellFont : "Sans"
                            font.pixelSize: 12
                            color: typeof rootShell !== "undefined" ? rootShell.colorSubtext : "#a6adc8"
                        }
                    }
                }

                Item { Layout.fillWidth: true }
            }

            // BLOCK 2: Inline Climate Row (Centered)
            RowLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter
                spacing: 6
                
                Item { Layout.fillWidth: true } // Left balance spacer
                Text { text: "cloud"; font.family: "Material Symbols Outlined"; font.pixelSize: 14; color: rootShell.colorAccent }
                Text { text: dashboardRoot.weatherDesc + "  •  Feels like " + dashboardRoot.weatherTemp; font.family: rootShell.shellFont; font.pixelSize: 11; color: rootShell.colorSubtext }
                Item { Layout.fillWidth: true } // Right balance spacer
            }

            // BLOCK 3: Horizontal Monitors Grid (4 Rings Line up side-by-side)
            RowLayout {
                Layout.fillWidth: true
                spacing: 4

                SysRing { label: "CPU"; value: dashboardRoot.sysCpu; ringColor: "#89b4fa" }
                SysRing { label: "GPU"; value: dashboardRoot.sysGpu; ringColor: "#f38ba8" }
                SysRing { label: "RAM"; value: dashboardRoot.sysRam; ringColor: "#a6e3a1" }
                SysRing { label: "DISK"; value: dashboardRoot.sysDisk; ringColor: "#f9e2af" }
            }

            // BLOCK 4: Primary Network/Bluetooth Toggle Rows (Grid matrix layout)
            GridLayout {
                columns: 2
                rowSpacing: 10; columnSpacing: 10
                Layout.fillWidth: true

                ToggleSwitch {
                    Layout.fillWidth: true
                    label: "Wi-Fi"; iconName: !dashboardRoot.wifiAvailable ? "wifi_off" : "wifi"
                    checked: dashboardRoot.wifiActive; isAvailable: dashboardRoot.wifiAvailable
                    onToggled: {
                        dashboardRoot.wifiActive = !dashboardRoot.wifiActive
                        wifiToggleProc.command = ["sh", "-c", "nmcli radio wifi | grep -q enabled && nmcli radio wifi off || nmcli radio wifi on"]
                        wifiToggleProc.running = true
                    }
                }

                ToggleSwitch {
                    Layout.fillWidth: true
                    label: "Bluetooth"; iconName: "bluetooth"; checked: dashboardRoot.btActive
                    onToggled: {
                        dashboardRoot.btActive = !dashboardRoot.btActive
                        btToggleProc.command = ["sh", "-c", "bluetoothctl show | grep -q 'Powered: yes' && bluetoothctl power off || bluetoothctl power on"]
                        btToggleProc.running = true
                    }
                }

                ToggleSwitch {
                    Layout.fillWidth: true
                    label: "Focus"; iconName: "do_not_disturb_on"; checked: dashboardRoot.dndActive
                    onToggled: dashboardRoot.dndActive = !dashboardRoot.dndActive
                }

                ToggleSwitch {
                    Layout.fillWidth: true
                    label: "Caffeine"; iconName: "coffee"; checked: dashboardRoot.caffeineActive
                    onToggled: {
                        dashboardRoot.caffeineActive = !dashboardRoot.caffeineActive
                        caffeineToggleProc.command = ["sh", "-c", "pkill -x hypridle && echo 'killed' || hypridle"]
                        caffeineToggleProc.running = true
                    }
                }
            }

            // BLOCK 5: Quick Utility Shortcuts Action Circles
            RowLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter
                spacing: 10

                // Inner inline generator logic loop
                Repeater {
                    model: [
                        { icon: "settings", cmd: "settings-layer-exec" },
                        { icon: "wallpaper", cmd: "hyprpicker -a" },
                        { icon: "apps", cmd: "rofi -show drun" },
                        { icon: "screenshot_region", cmd: "grimblast copysave area" },
                        { icon: "power_settings_new", cmd: "wlogout" }
                    ]
                    delegate: Rectangle {
                        width: 44; height: 44; radius: 22
                        color: Qt.rgba(rootShell.colorText.r, rootShell.colorText.g, rootShell.colorText.b, 0.1)
                        
                        Text { anchors.centerIn: parent; text: modelData.icon; font.family: "Material Symbols Outlined"; font.pixelSize: 18; color: rootShell.colorText }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: { actionCmdProc.command = ["sh", "-c", modelData.cmd]; actionCmdProc.running = true }
                        }
                    }
                }
            }

            // BLOCK 6: Volume Adjustment Dock
            DashboardSlider {
                id: volSlider
                Layout.fillWidth: true; height: 38
                iconLow: "volume_down"; iconHigh: "volume_up"; value: dashboardRoot.currentVolume
                onMoved: (newValue) => {
                    dashboardRoot.currentVolume = newValue;
                    setVolProc.command = ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", newValue.toFixed(2)]
                    setVolProc.running = true
                }
            }

            // BLOCK 7: Modular Audio Media Controller Interface Deck
            MediaControl {
                Layout.fillWidth: true
                onPlayPauseClicked: { actionCmdProc.command = ["playerctl", "play-pause"]; actionCmdProc.running = true }
                onPrevClicked: { actionCmdProc.command = ["playerctl", "previous"]; actionCmdProc.running = true }
                onNextClicked: { actionCmdProc.command = ["playerctl", "next"]; actionCmdProc.running = true }
            }

            // BLOCK 8: Embedded Active Stream Notification Box
            NotificationCenter {
                id: notificationArea
                Layout.fillWidth: true
                
                // Let the child component's implicitHeight math control the size dynamically
                visible: count > 0
            }
        }
    }
}