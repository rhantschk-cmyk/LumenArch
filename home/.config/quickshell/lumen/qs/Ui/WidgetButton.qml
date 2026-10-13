import QtQuick

Item {
    id: root
    property var bar: null
    property string text: ""
    property string tooltipText: ""
    property color foreground: "#cdd6f4"
    property int fixedWidth: 0
    property int fixedHeight: 0
    signal pressed(int button)

    implicitWidth: fixedWidth > 0 ? fixedWidth : 28
    implicitHeight: fixedHeight > 0 ? fixedHeight : 26

    Rectangle {
        anchors.fill: parent
        radius: 7
        color: mouseArea.containsMouse ? "#45475a" : "transparent"
    }

    Text {
        anchors.centerIn: parent
        text: root.text
        color: root.foreground
        font.family: root.bar && root.bar.fontFamily ? root.bar.fontFamily : "monospace"
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        onClicked: function(event) { root.pressed(event.button) }
    }
}
