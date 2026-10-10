import QtQuick 2.15
import SddmComponents 2.0

Rectangle {
    width: 1920
    height: 1080
    color: "#11111b"
    property int sessionIndex: session.index

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0; color: "#11111b" }
            GradientStop { position: 0.55; color: "#1e1e3a" }
            GradientStop { position: 1; color: "#302b63" }
        }
    }

    Rectangle {
        width: 700
        height: 700
        radius: 350
        color: "#33cba6f7"
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: -180
    }

    Column {
        anchors.centerIn: parent
        width: 380
        spacing: 12

        Text {
            text: "LUMEN"
            anchors.horizontalCenter: parent.horizontalCenter
            color: "#cdd6f4"
            font.pixelSize: 44
            font.bold: true
            font.letterSpacing: 8
        }
        Text {
            text: "Your focused Arch workspace"
            anchors.horizontalCenter: parent.horizontalCenter
            color: "#a6adc8"
            font.pixelSize: 15
        }
        Item { height: 14; width: 1 }

        Text { text: "Username"; color: "#cdd6f4"; font.pixelSize: 14 }
        TextBox {
            id: username
            width: parent.width
            height: 36
            text: userModel.lastUser
            font.pixelSize: 15
            KeyNavigation.tab: password
        }

        Text { text: "Password"; color: "#cdd6f4"; font.pixelSize: 14 }
        PasswordBox {
            id: password
            width: parent.width
            height: 36
            font.pixelSize: 15
            KeyNavigation.backtab: username
            KeyNavigation.tab: session
            Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    sddm.login(username.text, password.text, sessionIndex)
                    event.accepted = true
                }
            }
        }

        Text { text: "Session"; color: "#cdd6f4"; font.pixelSize: 14 }
        ComboBox {
            id: session
            width: parent.width
            height: 36
            model: sessionModel
            index: sessionModel.lastIndex
            font.pixelSize: 15
            KeyNavigation.backtab: password
            KeyNavigation.tab: loginButton
        }

        Button {
            id: loginButton
            width: parent.width
            text: "Enter Lumen"
            onClicked: sddm.login(username.text, password.text, sessionIndex)
            KeyNavigation.backtab: session
            KeyNavigation.tab: username
        }

        Text {
            text: Qt.formatDateTime(new Date(), "dddd · dd MMMM · hh:mm")
            anchors.horizontalCenter: parent.horizontalCenter
            color: "#bac2de"
        }
    }

    Connections {
        target: sddm
        function onLoginFailed() {
            password.text = ""
            password.forceActiveFocus()
        }
    }

    Component.onCompleted: {
        if (username.text === "")
            username.forceActiveFocus()
        else
            password.forceActiveFocus()
    }
}
