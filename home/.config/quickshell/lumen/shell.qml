import Quickshell
import Quickshell.Services.SystemTray
import QtQuick
import QtQuick.Layouts

ShellRoot {
    id: root
    property string timeText: Qt.formatDateTime(new Date(), "ddd dd MMM · HH:mm")

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.timeText = Qt.formatDateTime(new Date(), "ddd dd MMM · HH:mm")
    }

    Variants {
        model: Quickshell.screens
        delegate: Component {
            PanelWindow {
                required property var modelData
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
                        Text { text: "Hyprland"; color: "#bac2de" }
                        Item { Layout.fillWidth: true }
                        Text { text: root.timeText; color: "#cdd6f4"; font.family: "JetBrainsMono Nerd Font" }
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
