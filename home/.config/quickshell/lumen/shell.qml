import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.SystemTray
import QtQuick
import QtQuick.Layouts

ShellRoot {
    id: root
    property string timeText: Qt.formatDateTime(new Date(), "ddd dd MMM · HH:mm")
    property real previousCpuBusy: -1
    property real previousCpuTotal: -1
    property string cpuText: "CPU --%"
    property string ramText: "RAM --"

    function updateMetrics(output) {
        const values = output.trim().split(/\s+/)
        if (values.length !== 4)
            return

        const busy = Number(values[0])
        const total = Number(values[1])
        const usedMemory = Number(values[2])
        const totalMemory = Number(values[3])
        const elapsed = total - previousCpuTotal

        if (previousCpuTotal >= 0 && elapsed > 0)
            cpuText = "CPU " + Math.round(100 * (busy - previousCpuBusy) / elapsed) + "%"

        previousCpuBusy = busy
        previousCpuTotal = total
        ramText = "RAM " + (usedMemory / 1048576).toFixed(1) + "/" + (totalMemory / 1048576).toFixed(1) + "G"
    }

    Process {
        id: metricsProcess
        command: [
            "awk",
            '/^cpu / { idle = $5 + $6; total = 0; for (i = 2; i <= NF; i++) total += $i; busy = total - idle } /^MemTotal:/ { memoryTotal = $2 } /^MemAvailable:/ { memoryAvailable = $2 } END { printf "%d %d %d %d\\n", busy, total, memoryTotal - memoryAvailable, memoryTotal }',
            "/proc/stat",
            "/proc/meminfo"
        ]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.updateMetrics(this.text)
        }
    }

    Process {
        id: notificationCenter
        command: ["swaync-client", "-t"]
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.timeText = Qt.formatDateTime(new Date(), "ddd dd MMM · HH:mm")
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: metricsProcess.running = true
    }

    Variants {
        model: Quickshell.screens
        delegate: Component {
            PanelWindow {
                required property var modelData
                id: panel
                screen: modelData
                anchors { top: true; left: true; right: true }
                implicitHeight: 38
                color: "#dd1e1e2e"
                exclusiveZone: 38

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 5
                    radius: 10
                    color: "#ee313244"
                    border.color: "#66585b70"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        spacing: 10

                        Text { text: "󰣇  LUMEN"; color: "#cba6f7"; font.family: "JetBrainsMono Nerd Font"; font.bold: true }
                        Text { text: "•"; color: "#6c7086" }
                        Row {
                            spacing: 5
                            Repeater {
                                model: Hyprland.workspaces
                                delegate: Rectangle {
                                    required property var modelData
                                    visible: modelData.id > 0 && modelData.monitor === Hyprland.monitorFor(panel.screen)
                                    implicitWidth: 23
                                    implicitHeight: 23
                                    radius: 7
                                    color: modelData.focused ? "#cba6f7" : modelData.urgent ? "#f38ba8" : "#45475a"

                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.name
                                        color: modelData.focused ? "#1e1e2e" : "#cdd6f4"
                                        font.bold: modelData.focused
                                    }

                                    TapHandler { onTapped: modelData.activate() }
                                }
                            }
                        }
                        Item { Layout.fillWidth: true }
                        Text { text: "󰍛  " + root.cpuText; color: "#89b4fa"; font.family: "JetBrainsMono Nerd Font" }
                        Text { text: "󰘚  " + root.ramText; color: "#a6e3a1"; font.family: "JetBrainsMono Nerd Font" }
                        Text { text: root.timeText; color: "#cdd6f4"; font.family: "JetBrainsMono Nerd Font" }
                        Rectangle {
                            implicitWidth: 28
                            implicitHeight: 26
                            radius: 7
                            color: "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: "󰂚"
                                color: "#f9e2af"
                                font.family: "JetBrainsMono Nerd Font"
                            }

                            TapHandler { onTapped: notificationCenter.running = true }
                        }
                        Repeater {
                            model: SystemTray.items
                            delegate: Image {
                                required property var modelData
                                source: modelData.icon
                                sourceSize.width: 18
                                sourceSize.height: 18
                                implicitWidth: 20
                                implicitHeight: 20
                                TapHandler { onTapped: modelData.activate() }
                            }
                        }
                        Text { text: "󰂯"; color: "#a6e3a1"; font.family: "JetBrainsMono Nerd Font" }
                    }
                }
            }
        }
    }
}
