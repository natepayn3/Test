import QtQuick
import QtQuick.Shapes
import QtQuick.Layouts
import Quickshell.Io
import "../../configs"

Item {
    id: ringsRoot
    width: parent.width

    property real sysCpu: 0.0
    property real sysGpu: 0.0
    property real sysRam: 0.0
    property real sysDisk: 0.0

    property var lastCpuTotal: 0
    property var lastCpuIdle: 0

    FontConfig { id: fc }

    Timer {
        interval: 3000
        running: ringsRoot.visible
        repeat: true; triggeredOnStart: true
        onTriggered: { 
            cpuStatReader.reload();
            memInfoReader.reload();
            if (!diskGpuProc.running) diskGpuProc.running = true; 
        }
    }

    component StatRingItem : Item {
        id: ringRow
        width: 84  
        height: 84 

        property string label: ""
        property real value: 0.0

        Shape {
            anchors.fill: parent
            layer.enabled: true; layer.samples: 4

            // VECTOR OUTLINE LAYER: Active Progress Segment Drop-Shadow Only
            ShapePath {
                fillColor: "transparent"
                strokeColor: fc.overlayBackground
                strokeWidth: 5.5
                capStyle: ShapePath.RoundCap
                PathAngleArc { 
                    centerX: 42; centerY: 42; radiusX: 37; radiusY: 37 
                    startAngle: -90; sweepAngle: Math.max(0.1, ringRow.value * 360) 
                }
            }
            
            // Standard Translucent Track Background (No outline underneath)
            ShapePath {
                fillColor: "transparent"
                strokeColor: fc.trackBackground
                strokeWidth: 3.5 
                PathAngleArc { 
                    centerX: 42; centerY: 42; radiusX: 37; radiusY: 37 
                    startAngle: -90; sweepAngle: 360 
                }
            }

            // Standard Active Progress Indicator 
            ShapePath {
                fillColor: "transparent"
                strokeColor: "#ffffff"
                strokeWidth: 3.5 
                capStyle: ShapePath.RoundCap
                PathAngleArc { 
                    centerX: 42; centerY: 42; radiusX: 37; radiusY: 37 
                    startAngle: -90; sweepAngle: Math.max(0.1, ringRow.value * 360) 
                }
            }
        }

        Column {
            anchors.centerIn: parent
            spacing: -1

            Text {
                text: ringRow.label
                color: fc.textMuted
                font.family: fc.mainFont
                font.pixelSize: 10 
                font.weight: Font.Bold
                anchors.horizontalCenter: parent.horizontalCenter
                Component.onCompleted: {
                    fc.applyOutline(this, fc.overlayBackground)
                }
            }
            Text {
                text: Math.round(ringRow.value * 100) + "%"
                color: "#ffffff"
                font.family: fc.mainFont
                font.pixelSize: 12 
                font.weight: Font.DemiBold
                anchors.horizontalCenter: parent.horizontalCenter
                Component.onCompleted: {
                    fc.applyOutline(this, fc.overlayBackground)
                }
            }
        }
    }

    // --- DYNAMIC SEPARATION COLUMN TRACKER ---
    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        StatRingItem { 
            label: "CPU"
            value: ringsRoot.sysCpu
            Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
        }
        StatRingItem { 
            label: "GPU"
            value: ringsRoot.sysGpu
            Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
        }
        StatRingItem { 
            label: "RAM"
            value: ringsRoot.sysRam
            Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
        }
        StatRingItem { 
            label: "DISK"
            value: ringsRoot.sysDisk
            Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
        }
    }

    FileView {
        id: memInfoReader
        path: "/proc/meminfo"
        onTextChanged: {
            let lines = text().split('\n'), total = 0, avail = 0;
            for (let i = 0; i < lines.length; i++) {
                if (lines[i].startsWith("MemTotal:")) total = parseInt(lines[i].replace(/\D/g, ''));
                if (lines[i].startsWith("MemAvailable:")) avail = parseInt(lines[i].replace(/\D/g, ''));
            }
            if (total > 0) ringsRoot.sysRam = (total - avail) / total;
        }
    }

    FileView {
        id: cpuStatReader
        path: "/proc/stat"
        onTextChanged: {
            let parts = text().split('\n')[0].split(/\s+/).filter(Boolean);
            if (parts.length >= 5) {
                let user = parseInt(parts[1])||0, nice = parseInt(parts[2])||0, sys = parseInt(parts[3])||0, idle = parseInt(parts[4])||0, io = parseInt(parts[5])||0, irq = parseInt(parts[6])||0, soft = parseInt(parts[7])||0;
                let total = user + nice + sys + idle + io + irq + soft;
                let totalDelta = total - ringsRoot.lastCpuTotal, idleDelta = idle - ringsRoot.lastCpuIdle;
                if (totalDelta > 0) ringsRoot.sysCpu = (totalDelta - idleDelta) / totalDelta;
                ringsRoot.lastCpuTotal = total; ringsRoot.lastCpuIdle = idle;
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
                        ringsRoot.sysGpu = rawGpu / 100.0;
                        let rawDisk = parseFloat(lines[1]) || 0.0;
                        ringsRoot.sysDisk = rawDisk / 100.0;
                    }
                } catch(e) {}
                diskGpuProc.running = false;
            }
        }
    }
}