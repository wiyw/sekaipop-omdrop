import QtQuick

// A switch in the theme's outline style, with the accent gradient when on.
Item {
    id: root

    required property var theme
    required property var pal
    property bool checked: false

    signal toggled()

    implicitWidth: 42
    implicitHeight: 24

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        border.width: 2.5
        border.color: root.checked ? root.theme.colBorder : root.pal.line
        color: root.checked ? "transparent" : root.pal.surface
        gradient: root.checked ? onGradient : null

        Gradient {
            id: onGradient
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: root.theme.accentMint }
            GradientStop { position: 1; color: root.theme.accentCyan }
        }
    }

    Rectangle {
        width: 16
        height: 16
        radius: 8
        y: 4
        x: root.checked ? root.width - width - 4 : 4
        color: root.checked ? root.theme.colBorder : root.pal.inkSub

        Behavior on x {
            NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }
}
