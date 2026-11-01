import QtQuick
import "lib"
import "lib/Omdrop.js" as O

// The bar entry (SekaiPop draws the pill around it and opens the popup on a left click).
// The icon says whether this computer is receiving; next to it the time left, or "Off",
// "Hidden", "Missing". On a standing bar the words go under the icon.
//
//   on        the icon, "9:58" / "On"; amber dot when the window is nearly over
//   waiting   the icon, "Hidden"; amber dot (receiving, but nobody can see us)
//   starting  the icon, three dots blinking
//   off       the icon dimmed, "Off" dimmed
//   missing   the icon dimmed and struck through
//   error     the icon, "Error"
// "Icon only" leaves the words out and puts a state dot on the icon instead.
Item {
    id: root

    required property var host

    readonly property var svc: root.host.service
    readonly property var m: root.svc ? root.svc.model : O.emptyModel("off")
    readonly property real now: root.svc ? root.svc.now : Date.now()
    readonly property bool iconOnly: root.host.settings.barLook === "icon"
    readonly property bool vertical: root.host.bar.vertical
    readonly property string st: root.m.state

    readonly property string text: O.entryText(root.m, root.iconOnly)
    readonly property bool dim: st === "off" || st === "missing" || st === "error"
    readonly property bool struck: st === "missing"
    readonly property bool dots: st === "starting" && !root.iconOnly
    readonly property bool attention: O.isUrgent(root.m)
    readonly property bool soon: st === "on" && root.m.remaining !== null
        && root.m.remaining > 0 && root.m.remaining <= 60
    readonly property string dot: root.iconOnly ? O.entryDot(root.m) : (root.soon ? "soon" : "")

    // SekaiPop reads these two.
    property string tip: O.entryTip(root.m)
    property bool present: !(st === "missing" && root.host.settings.hideWhenMissing)

    implicitWidth: layout.implicitWidth
    implicitHeight: layout.implicitHeight

    Grid {
        id: layout
        columns: root.vertical ? 1 : 3
        rowSpacing: 2
        columnSpacing: 7
        horizontalItemAlignment: Grid.AlignHCenter
        verticalItemAlignment: Grid.AlignVCenter

        Item {
            width: 18
            height: 18

            Icon {
                theme: root.host.theme
                anchors.fill: parent
                name: "wifi_tethering"
                size: 18
                color: root.dim ? root.host.bar.inkSub : root.host.bar.ink
            }

            Rectangle {
                visible: root.struck
                anchors.centerIn: parent
                width: 22
                height: 2.5
                radius: 1.25
                rotation: -45
                antialiasing: true
                color: root.host.bar.ink
            }

            Rectangle {
                visible: root.attention && !root.iconOnly
                x: parent.width - 5
                y: -3
                width: 8
                height: 8
                radius: 4
                color: root.host.theme.warnFill
                border.width: 1.5
                border.color: root.host.bar.ink
            }

            Rectangle {
                visible: root.dot !== ""
                x: parent.width - 5
                y: parent.height - 6
                width: 9
                height: 9
                radius: 4.5
                color: root.dot === "on" ? root.host.theme.accentMint
                    : root.dot === "error" ? root.host.theme.warnFill
                    : root.dot === "waiting" || root.dot === "soon" ? root.host.theme.warnFill
                    : root.host.theme.surface
                border.width: 2
                border.color: root.dot === "on" ? root.host.theme.colBorder : root.host.bar.ink
            }
        }

        Text {
            visible: root.text !== ""
            text: root.text
            color: root.dim ? root.host.bar.inkSub : root.host.bar.ink
            font.family: root.host.theme.fontFamily
            font.pixelSize: root.vertical ? 11 : 12
            font.weight: Font.ExtraBold
            font.styleName: root.host.theme.fontStyleBold
            font.features: ({ "tnum": 1 })
        }

        Row {
            visible: root.dots
            spacing: 2
            height: 6

            Repeater {
                model: 3

                delegate: Rectangle {
                    required property int index
                    width: 3
                    height: 3
                    radius: 1.5
                    anchors.verticalCenter: parent.verticalCenter
                    color: root.host.bar.ink

                    SequentialAnimation on opacity {
                        running: root.dots
                        loops: Animation.Infinite
                        PauseAnimation { duration: index * 200 }
                        NumberAnimation { to: 0.2; duration: 600 }
                        NumberAnimation { to: 1; duration: 600 }
                        PauseAnimation { duration: (2 - index) * 200 }
                    }
                }
            }
        }
    }
}
