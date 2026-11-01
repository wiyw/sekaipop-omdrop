import QtQuick

// A small key drawn like the shell's (outline, surface, hard shadow that it presses into).
// `lit` is the accent gradient, pressed down ("Copied"); `big` is a call to action.
Item {
    id: root

    required property var theme
    // The surface family it sits on: { surface, surfaceHover, ink, line, lineShadow, ringWhite }.
    required property var pal
    property string icon: ""
    property string text: ""
    property bool lit: false
    property bool big: false
    property real keyHeight: root.big ? 38 : 28
    property real fontSize: root.big ? 14 : 11
    property real iconSize: root.big ? 16 : 13

    signal clicked()

    readonly property bool down: area.pressed || root.lit
    readonly property real shadow: root.big ? 4 : 3

    implicitWidth: root.text === "" ? root.keyHeight : row.implicitWidth + (root.big ? 32 : 18)
    implicitHeight: root.keyHeight + root.shadow

    Rectangle {
        y: root.shadow
        width: parent.width
        height: root.keyHeight
        radius: face.radius
        color: root.pal.lineShadow
        visible: !root.down
    }

    Rectangle {
        id: face
        y: root.down ? root.shadow : 0
        width: parent.width
        height: root.keyHeight
        radius: root.big ? 13 : 9
        border.width: root.big ? 3 : 2.5
        border.color: root.lit || root.big ? root.theme.colBorder : root.pal.line
        color: area.containsMouse && !root.lit && !root.big ? root.pal.surfaceHover : root.pal.surface
        gradient: root.lit || root.big ? accent : null

        Gradient {
            id: accent
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: root.theme.accentMint }
            GradientStop { position: 1; color: root.theme.accentCyan }
        }

        Row {
            id: row
            anchors.centerIn: parent
            spacing: root.big ? 8 : 5

            Icon {
                theme: root.theme
                visible: root.icon !== ""
                anchors.verticalCenter: parent.verticalCenter
                name: root.icon
                size: root.iconSize
                color: root.lit || root.big ? root.theme.colBorder : root.pal.ink
            }

            Text {
                visible: root.text !== ""
                anchors.verticalCenter: parent.verticalCenter
                text: root.text
                color: root.lit || root.big ? root.theme.colBorder : root.pal.ink
                font.family: root.theme.fontFamily
                font.pixelSize: root.fontSize
                font.weight: Font.ExtraBold
                font.styleName: root.theme.fontStyleBold
            }
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
