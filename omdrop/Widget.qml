import QtQuick
import "lib"
import "lib/Omdrop.js" as O

// The desktop widget, inside SekaiPop's card frame (so it uses the card family of colours,
// pSurface / pInk, like the built-in cards).
//
//   full      the badge, "Omdrop", this computer and the state; the radar; then the nearby
//             devices, a click sending files. 340 wide inside the frame.
//   compact   a 148 square: the icon, how many are nearby, and the radar, no words.
//
// The header and margins are plain card, which SekaiPop keeps as the handle for dragging.
Item {
    id: root

    required property var host

    readonly property var t: root.host.theme
    readonly property var svc: root.host.service
    readonly property var m: root.svc ? root.svc.model : O.emptyModel("off")
    readonly property real now: root.svc ? root.svc.now : Date.now()
    readonly property string st: root.m.state
    readonly property bool compact: root.host.settings.look === "compact"
    readonly property var peers: root.svc ? O.sortedPeers(root.svc.peers) : []
    readonly property bool canReceive: st === "on" || st === "waiting" || st === "starting"
    readonly property var shown: root.peers.slice(0, 4)

    // The card's family of colours.
    readonly property var pal: ({
        surface: root.t.pSurface,
        surfaceHover: root.t.pSurfaceHover,
        surfaceDivider: root.t.pSurfaceDivider,
        ink: root.t.pInk,
        inkSub: root.t.pInkSub,
        line: root.t.pLine,
        lineShadow: root.t.pLineShadow,
        ringWhite: root.t.pRingWhite
    })

    implicitWidth: root.compact ? 148 : 340
    implicitHeight: root.compact ? 148 : full.implicitHeight

    // ===== full =====
    Column {
        id: full
        visible: !root.compact
        width: parent.width
        spacing: 3

        Item {
            width: parent.width
            height: 46

            Rectangle {
                id: badge
                x: 2
                anchors.verticalCenter: parent.verticalCenter
                width: 34
                height: 34
                radius: 11
                border.width: 2.5
                border.color: root.t.pLine
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: root.t.accentMint }
                    GradientStop { position: 1; color: root.t.accentCyan }
                }

                Icon {
                    anchors.centerIn: parent
                    theme: root.t
                    name: "wifi_tethering"
                    size: 19
                    color: root.t.pInk
                }
            }

            Column {
                anchors.left: badge.right
                anchors.leftMargin: 8
                anchors.right: chip.left
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1

                Text {
                    text: "Omdrop"
                    color: root.t.pInk
                    font.family: root.t.fontFamily
                    font.pixelSize: 16
                    font.weight: Font.ExtraBold
                    font.styleName: root.t.fontStyleBold
                }

                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: root.m.name !== "" ? root.m.name : "this computer"
                    color: root.t.pInkSub
                    font.family: root.t.fontFamily
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                }
            }

            StatusChip {
                id: chip
                theme: root.t
                pal: root.pal
                chipHeight: 26
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                kind: root.svc && root.svc.busy ? "starting" : root.st
                text: root.svc && root.svc.busy
                    ? root.svc.busyText + "…"
                    : (O.STATE_WORDS[root.st] || "")
            }
        }

        Row {
            width: parent.width
            spacing: 8

            Text {
                width: parent.width - actionKey.width - 8
                anchors.verticalCenter: parent.verticalCenter
                wrapMode: Text.WordWrap
                text: root.svc && root.svc.lastError !== "" ? root.svc.lastError : O.detailText(root.m)
                color: root.svc && root.svc.lastError !== "" ? root.t.warnFill : root.t.pInkSub
                font.family: root.t.fontFamily
                font.pixelSize: 12
                font.weight: Font.DemiBold
                lineHeight: 1.25
            }

            KeyCap {
                id: actionKey
                theme: root.t
                pal: root.pal
                icon: root.canReceive ? "stop_circle" : "play_arrow"
                text: root.canReceive ? "Stop" : "Start"
                onClicked: root.svc.toggle()
            }
        }

        Radar {
            width: full.width
            height: 178
            theme: root.t
            peers: root.svc ? root.svc.peers : []
            scanning: root.svc ? root.svc.scanning : false
            muted: !root.host.settings.radarSound
            soundDir: String(Qt.resolvedUrl("sounds/")).replace("file://", "")
            onSendRequested: function (mac) { root.svc.sendTo(mac) }
        }

        Repeater {
            model: root.shown

            delegate: PeerRow {
                required property var modelData
                width: full.width
                theme: root.t
                pal: root.pal
                peer: modelData
                sending: root.svc.sendActive && root.svc.sendingTo === modelData.mac
                sendStatus: root.svc.sendingTo === modelData.mac ? root.svc.sendStatus : ""
                sendDone: root.svc.sendingTo === modelData.mac && root.svc.sendDone
                sendFailed: root.svc.sendingTo === modelData.mac && root.svc.sendFailed
                onSendRequested: function (mac) { root.svc.sendTo(mac) }
                onCancelRequested: root.svc.cancelSend()
                onDismissRequested: root.svc.dismissSend()
            }
        }

        Text {
            visible: root.peers.length > 4
            x: 4
            text: "+" + (root.peers.length - 4) + " more in the bar's popup"
            color: root.t.pInkSub
            font.family: root.t.fontFamily
            font.pixelSize: 11
            font.weight: Font.Bold
        }

        Text {
            visible: root.canReceive && root.peers.length === 0
            x: 4
            width: parent.width - 8
            topPadding: 2
            wrapMode: Text.WordWrap
            text: root.svc && root.svc.scanning
                ? "Nothing nearby yet. On an iPhone, the AirDrop sheet has to be open."
                : "Waiting for the radio to start advertising…"
            color: root.t.pInkSub
            font.family: root.t.fontFamily
            font.pixelSize: 12
            font.weight: Font.DemiBold
            lineHeight: 1.25
        }

        Text {
            visible: !root.canReceive
            x: 4
            width: parent.width - 8
            topPadding: 2
            wrapMode: Text.WordWrap
            text: "Omdrop is off. Press Start to be visible to nearby Apple devices."
            color: root.t.pInkSub
            font.family: root.t.fontFamily
            font.pixelSize: 12
            font.weight: Font.DemiBold
            lineHeight: 1.25
        }

        Item { width: 1; height: 2 }
    }

    // ===== compact =====
    Column {
        visible: root.compact
        anchors.centerIn: parent
        width: parent.width
        spacing: 3

        Icon {
            anchors.horizontalCenter: parent.horizontalCenter
            theme: root.t
            name: "wifi_tethering"
            size: 18
            color: root.canReceive ? root.t.pInk : root.t.pInkSub
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.canReceive ? String(root.peers.length) : "Off"
            color: root.t.pInk
            font.family: root.t.fontFamily
            font.pixelSize: 22
            font.weight: Font.ExtraBold
            font.styleName: root.t.fontStyleBold
            font.features: ({ "tnum": 1 })
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.canReceive ? "nearby" : "Omdrop"
            color: root.t.pInkSub
            font.family: root.t.fontFamily
            font.pixelSize: 10
            font.weight: Font.DemiBold
        }

        Radar {
            width: 72
            height: 72
            anchors.horizontalCenter: parent.horizontalCenter
            theme: root.t
            peers: root.svc ? root.svc.peers : []
            scanning: root.svc ? root.svc.scanning : false
            labels: false
            showEmptyText: false
            interactive: false
            muted: true
        }
    }
}
