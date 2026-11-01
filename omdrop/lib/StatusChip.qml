import QtQuick

// The receiver's state in the header: "Receiving" on the accent gradient with a dark dot, any
// other state on the plain surface with a hollow one, and a small spinner while starting.
Item {
    id: root

    required property var theme
    required property var pal
    property string kind: "on"
    property string text: ""
    property real chipHeight: 28

    readonly property bool on: root.kind === "on"
    readonly property bool urgent: root.kind === "waiting" || root.kind === "error"

    implicitWidth: row.implicitWidth + 22
    implicitHeight: root.chipHeight

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        border.width: 2.5
        border.color: root.on ? root.theme.colBorder
            : root.urgent ? root.theme.warnFill : root.pal.line
        color: root.pal.surface
        gradient: root.on ? accent : null

        Gradient {
            id: accent
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: root.theme.accentMint }
            GradientStop { position: 1; color: root.theme.accentCyan }
        }

        Rectangle {
            visible: root.on
            anchors.fill: parent
            anchors.margins: 2.5
            radius: height / 2
            color: "transparent"
            border.width: 2
            border.color: root.pal.ringWhite
        }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6

        Item {
            width: 9
            height: 9
            anchors.verticalCenter: parent.verticalCenter

            Rectangle {
                visible: root.kind !== "starting"
                anchors.fill: parent
                radius: width / 2
                color: root.on ? root.theme.colBorder
                    : root.urgent ? root.theme.warnFill : "transparent"
                border.width: root.on || root.urgent ? 0 : 2
                border.color: root.pal.inkSub
            }

            // starting: a ring with a gap, turning
            Rectangle {
                visible: root.kind === "starting"
                anchors.fill: parent
                radius: width / 2
                color: "transparent"
                border.width: 2.5
                border.color: root.pal.ink
                RotationAnimation on rotation {
                    running: root.kind === "starting" && root.visible
                    from: 0
                    to: 360
                    duration: 800
                    loops: Animation.Infinite
                }

                Rectangle {
                    width: 4
                    height: 4
                    x: parent.width - 3
                    y: parent.height / 2 - 2
                    color: root.pal.surface
                }
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.text
            color: root.on ? root.theme.colBorder : root.pal.ink
            font.family: root.theme.fontFamily
            font.pixelSize: 12
            font.weight: Font.ExtraBold
            font.styleName: root.theme.fontStyleBold
        }
    }
}
