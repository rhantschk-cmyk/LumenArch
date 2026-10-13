import QtQuick
import qs.Commons
import qs.Ui

BarWidget {
    id: root
    moduleName: "rhantschk-cmyk.lumen"
    implicitWidth: button.implicitWidth
    implicitHeight: button.implicitHeight

    WidgetButton {
        id: button
        anchors.fill: parent
        bar: root.bar
        text: "󰣇"
        tooltipText: "Open Lumen Control Center"
        foreground: Color.accent
        fixedWidth: root.bar && root.bar.vertical ? -1 : Style.space(27)
        fixedHeight: root.bar && root.bar.vertical ? Style.space(26) : -1

        onPressed: function(button) {
            if (button !== Qt.LeftButton || !root.bar)
                return

            root.bar.run("if command -v lumen >/dev/null 2>&1; then xdg-terminal-exec -e lumen center; else notify-send 'Lumen Control Center unavailable' 'Install Lumen first; this plugin never installs packages or uses sudo.'; fi")
        }
    }
}
