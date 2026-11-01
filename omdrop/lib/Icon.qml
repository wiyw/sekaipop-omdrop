import QtQuick

// A Material Symbols icon by name, in the theme's icon font (a plugin can't use the shell's own
// MaterialIcon, which also follows the shell's other icon styles: these stay Material).
Text {
    id: root

    required property var theme
    property string name: ""
    property real size: 18
    property real fill: 0

    width: root.size
    height: root.size
    text: root.name
    color: root.theme.ink
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
    font.family: root.theme.iconFont
    font.pixelSize: root.size
    font.variableAxes: ({ "FILL": root.fill, "wght": 500, "opsz": Math.max(20, Math.min(48, root.size)), "GRAD": 0 })
}
