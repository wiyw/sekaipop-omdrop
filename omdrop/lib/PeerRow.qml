import QtQuick
import "Omdrop.js" as O

// One nearby device: its name (or address), its signal, and the key that sends it a file.
// A send in progress owns the row until it finishes or is cancelled.
Item {
    id: root

    required property var theme
    required property var pal
    property var peer: null
    property bool sending: false
    property string sendStatus: ""
    property bool sendDone: false
    property bool sendFailed: false

    signal sendRequested(string mac)
    signal cancelRequested()
    signal dismissRequested()

    readonly property string mac: root.peer ? root.peer.mac : ""
    readonly property string name: root.peer ? O.peerLabel(root.peer) : ""
    readonly property bool named: root.peer && root.peer.name !== ""
    readonly property string phase: O.sendPhase(root.sending, root.sendDone, root.sendFailed)

    implicitHeight: root.phase === "idle" ? 46 : 64
    width: parent ? parent.width : 320

    Rectangle {
        anchors.fill: parent
        radius: 10
        color: mouse.containsMouse && !root.sending ? root.pal.surfaceHover : "transparent"
    }

    Column {
        anchors.left: parent.left
        anchors.leftMargin: 10
        anchors.right: key.left
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        Text {
            width: parent.width
            elide: Text.ElideRight
            text: root.name
            textFormat: Text.PlainText
            color: root.named ? root.pal.ink : root.pal.inkSub
            font.family: root.theme.fontFamily
            font.pixelSize: 14
            font.weight: root.named ? Font.ExtraBold : Font.DemiBold
            font.styleName: root.named ? root.theme.fontStyleBold : ""
        }

        Text {
            width: parent.width
            elide: Text.ElideRight
            text: root.sending ? root.sendStatus
                : root.sendDone ? "Sent"
                : root.sendFailed ? root.sendStatus
                : (root.peer ? O.signalText(root.peer) : "")
            color: root.sendFailed ? root.theme.warnFill : root.pal.inkSub
            font.family: root.theme.fontFamily
            font.pixelSize: 11
            font.weight: Font.DemiBold
        }
    }

    Rectangle {
        id: track
        anchors.left: parent.left
        anchors.leftMargin: 10
        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 4
        height: 3
        radius: height / 2
        visible: root.phase !== "idle"
        color: Qt.rgba(root.pal.line.r, root.pal.line.g, root.pal.line.b, 0.35)
        clip: true

        Rectangle {
            id: segment
            visible: root.phase === "working"
            width: track.width * 0.3
            height: parent.height
            radius: parent.radius
            color: root.pal.ink

            NumberAnimation on x {
                running: segment.visible && track.visible
                loops: Animation.Infinite
                from: -segment.width
                to: track.width
                duration: 1100
                easing.type: Easing.InOutQuad
            }
        }

        Rectangle {
            visible: root.phase === "done" || root.phase === "failed"
            anchors.fill: parent
            radius: parent.radius
            color: root.phase === "failed" ? root.theme.warnFill : root.pal.ink
        }
    }

    KeyCap {
        id: key
        theme: root.theme
        pal: root.pal
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        icon: root.sending ? "close" : root.sendDone ? "check" : root.sendFailed ? "refresh" : "send"
        lit: root.sendDone
        onClicked: {
            if (root.sending)
                root.cancelRequested()
            else if (root.sendDone || root.sendFailed)
                root.dismissRequested()
            else
                root.sendRequested(root.mac)
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        hoverEnabled: true
        enabled: !root.sending
    }
}
