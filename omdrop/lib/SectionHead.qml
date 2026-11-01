import QtQuick

// "NEARBY · 3 SEEN": a list's heading, the count in full ink.
Item {
    id: root

    required property var theme
    required property var pal
    property string label: ""
    property string value: ""

    width: parent ? parent.width : 300
    implicitHeight: 38

    Row {
        x: 16
        y: 14
        spacing: 8

        Text {
            text: root.label.toUpperCase()
            color: root.pal.inkSub
            font.family: root.theme.fontFamily
            font.pixelSize: 11
            font.weight: Font.ExtraBold
            font.letterSpacing: 1.1
        }

        Text {
            visible: root.value !== ""
            text: "·"
            color: root.pal.inkSub
            font.family: root.theme.fontFamily
            font.pixelSize: 11
            font.weight: Font.ExtraBold
        }

        Text {
            text: root.value.toUpperCase()
            color: root.pal.ink
            font.family: root.theme.fontFamily
            font.pixelSize: 11
            font.weight: Font.ExtraBold
            font.letterSpacing: 1.1
        }
    }
}
