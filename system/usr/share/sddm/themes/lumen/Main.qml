import QtQuick 2.15
import QtQuick.Controls 2.15
import SddmComponents 2.0

Rectangle {
    width: 1920; height: 1080
    color: "#11111b"
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0; color: "#11111b" }
            GradientStop { position: 0.55; color: "#1e1e3a" }
            GradientStop { position: 1; color: "#302b63" }
        }
    }
    Rectangle { width: 700; height: 700; radius: 350; color: "#33cba6f7"; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: -180 }
    Column {
        anchors.centerIn: parent; width: 380; spacing: 18
        Text { text: "LUMEN"; anchors.horizontalCenter: parent.horizontalCenter; color: "#cdd6f4"; font.pixelSize: 44; font.bold: true; font.letterSpacing: 8 }
        Text { text: "Your focused Arch workspace"; anchors.horizontalCenter: parent.horizontalCenter; color: "#a6adc8"; font.pixelSize: 15 }
        Item { height: 14; width: 1 }
        TextField { id: username; width: parent.width; placeholderText: "Username"; text: userModel.lastUser; color: "#cdd6f4"; placeholderTextColor: "#a6adc8" }
        TextField { id: password; width: parent.width; placeholderText: "Password"; echoMode: TextInput.Password; color: "#cdd6f4"; placeholderTextColor: "#a6adc8"; onAccepted: loginButton.clicked() }
        ComboBox { id: session; width: parent.width; model: sessionModel; textRole: "name"; currentIndex: sessionModel.lastIndex }
        Button { id: loginButton; width: parent.width; text: "Enter Lumen"; onClicked: sddm.login(username.text, password.text, session.currentIndex) }
        Text { text: Qt.formatDateTime(new Date(), "dddd · dd MMMM · hh:mm"); anchors.horizontalCenter: parent.horizontalCenter; color: "#bac2de" }
    }
    Connections { target: sddm; function onLoginFailed() { password.text = ""; password.forceActiveFocus() } }
}
