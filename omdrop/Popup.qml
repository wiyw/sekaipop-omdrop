import QtQuick
import Quickshell.Io
import Qt.labs.folderlistmodel
import "lib"
import "lib/Omdrop.js" as O

// The card under the bar entry (SekaiPop draws the card, places it and closes it on a click
// away or Escape; this is its face).
//
//   header    the badge, "Omdrop", this computer's name and window, the state chip
//   hero      what is happening in one sentence, and the switch that starts/stops receiving
//   window    the eight stops, a live window showing what is left
//   who       Everyone / Contacts Only, the computer's name, the folder
//   senders   the Contacts Only allow-list, when that is the audience
//   nearby    the nearby Apple devices; click one to send it files
//   footer    when status was last checked
//
// Past the card's height it scrolls, so every device and setting stays reachable.
Item {
    id: root

    required property var host

    readonly property var t: root.host.theme
    readonly property var svc: root.host.service
    readonly property var m: root.svc ? root.svc.model : O.emptyModel("off")
    readonly property real now: root.svc ? root.svc.now : Date.now()
    readonly property string st: root.m.state

    // A popup sits on the bar's surface, not a card's.
    readonly property var pal: ({
        surface: root.t.surface,
        surfaceHover: root.t.surfaceHover,
        surfaceDivider: root.t.surfaceDivider,
        ink: root.t.ink,
        inkSub: root.t.inkSub,
        line: root.t.line,
        lineShadow: root.t.lineShadow,
        ringWhite: root.t.ringWhite
    })

    readonly property var windowArg: O.activeWindow(root.m, root.host.settings.window)
    readonly property var peers: root.svc ? O.sortedPeers(root.svc.peers) : []
    readonly property bool canReceive: root.st === "on" || root.st === "waiting" || root.st === "starting"
    readonly property string lastError: root.svc ? root.svc.lastError : ""
    readonly property bool errored: root.lastError !== ""
    readonly property string detail: root.errored ? root.lastError : O.detailText(root.m)

    property string nameDraft: ""
    property string senderDraft: ""

    implicitWidth: 360
    implicitHeight: Math.min(col.implicitHeight, root.host.popup.maxHeight - 18)

    function setNameDraft(value) {
        root.nameDraft = value
        nameField.text = value
    }

    function renameNow() {
        if (root.nameDraft.trim() !== "" && root.nameDraft.trim() !== root.m.name)
            root.svc.rename(root.nameDraft)
    }

    function addSenderNow() {
        if (root.senderDraft.trim() === "")
            return
        root.svc.addSender(root.senderDraft)
        root.senderDraft = ""
        senderField.text = ""
    }

    // The receiver writes each shared link into the download folder as an inert .url/.webloc.
    // FolderListModel watches it, so a link that arrives while the popup is open appears here.
    readonly property int linkLimit: 4

    FolderListModel {
        id: links
        folder: O.fileUrl(root.m.dir)
        nameFilters: ["*.url", "*.webloc"]
        showDirs: false
        showFiles: true
        showHidden: false
        sortCaseSensitive: false
        sortField: FolderListModel.Time
        sortReversed: false
    }

    Component.onCompleted: {
        root.setNameDraft(root.m.name)
        root.svc.refresh()
        root.svc.refreshSenders()
    }

    Connections {
        target: root.host.popup
        function onOpenChanged() {
            if (!root.host.popup.open)
                return
            root.svc.refresh()
            root.svc.refreshSenders()
            root.setNameDraft(root.m.name)
        }
    }

    Connections {
        target: root.svc
        function onModelChanged() {
            if (!nameField.activeFocus)
                root.setNameDraft(root.m.name)
        }
    }

    Flickable {
        id: flick
        width: parent.width
        height: root.implicitHeight
        contentWidth: width
        contentHeight: col.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        Column {
            id: col
            width: flick.width
            spacing: 0

            // ===== header =====
            Item {
                width: parent.width
                height: 62

                Rectangle {
                    id: badge
                    x: 13
                    anchors.verticalCenter: parent.verticalCenter
                    width: 40
                    height: 40
                    radius: 13
                    border.width: 2.5
                    border.color: root.t.colBorder
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: root.t.accentMint }
                        GradientStop { position: 1; color: root.t.accentCyan }
                    }

                    Icon {
                        anchors.centerIn: parent
                        theme: root.t
                        name: "wifi_tethering"
                        size: 22
                        color: root.t.colBorder
                    }
                }

                Column {
                    anchors.left: badge.right
                    anchors.leftMargin: 9
                    anchors.right: chip.left
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1

                    Text {
                        text: "Omdrop"
                        color: root.t.ink
                        font.family: root.t.fontFamily
                        font.pixelSize: 17
                        font.weight: Font.ExtraBold
                        font.styleName: root.t.fontStyleBold
                    }

                    Text {
                        width: parent.width
                        elide: Text.ElideRight
                        text: root.m.name !== ""
                            ? root.m.name + (root.m.remaining !== null && root.m.remaining > 0
                                ? " · " + O.formatRemaining(root.m.remaining) : "")
                            : O.windowLabel(root.windowArg)
                        color: root.t.inkSub
                        font.family: root.t.fontFamily
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                        font.features: ({ "tnum": 1 })
                    }
                }

                StatusChip {
                    id: chip
                    theme: root.t
                    pal: root.pal
                    anchors.right: parent.right
                    anchors.rightMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    kind: root.svc && root.svc.busy ? "starting" : root.st
                    text: root.svc && root.svc.busy
                        ? root.svc.busyText + "…"
                        : (O.STATE_WORDS[root.st] || "")
                }
            }

            // ===== hero =====
            Rectangle {
                x: 12
                width: parent.width - 24
                height: hero.implicitHeight + 22
                radius: 14
                color: root.pal.surfaceHover
                border.width: 2
                border.color: root.pal.line

                Column {
                    id: hero
                    x: 13
                    y: 11
                    width: parent.width - 26
                    spacing: 9

                    Row {
                        width: parent.width
                        spacing: 10

                        Text {
                            width: parent.width - powerKey.width - 10
                            anchors.verticalCenter: parent.verticalCenter
                            wrapMode: Text.WordWrap
                            text: root.detail
                            color: root.errored || O.isUrgent(root.m) ? root.t.warnFill : root.t.ink
                            font.family: root.t.fontFamily
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                            lineHeight: 1.25
                        }

                        KeyCap {
                            id: powerKey
                            theme: root.t
                            pal: root.pal
                            big: true
                            lit: root.canReceive
                            icon: root.canReceive ? "stop_circle" : "play_arrow"
                            text: root.canReceive ? "Stop" : "Start"
                            onClicked: root.svc.toggle()
                        }
                    }

                    Column {
                        visible: root.svc && root.svc.doctor.missing.length > 0
                            && (!root.canReceive || root.st === "waiting")
                        width: parent.width
                        spacing: 3

                        Repeater {
                            model: root.svc ? root.svc.doctor.missing : []

                            delegate: Text {
                                required property var modelData
                                width: hero.width
                                wrapMode: Text.WordWrap
                                text: "• " + modelData.say
                                color: root.t.warnFill
                                font.family: root.t.fontFamily
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                            }
                        }
                    }
                }
            }

            // ===== how long =====
            SectionHead {
                theme: root.t
                pal: root.pal
                label: "Stay visible for"
                value: root.canReceive ? O.windowLabel(root.windowArg) : "next time"
            }

            Flow {
                x: 12
                width: parent.width - 24
                spacing: 5
                height: childrenRect.height

                Repeater {
                    model: O.WINDOW_STOPS

                    delegate: KeyCap {
                        required property var modelData
                        theme: root.t
                        pal: root.pal
                        text: modelData.short
                        lit: modelData.arg === root.windowArg
                        onClicked: root.svc.chooseWindow(modelData.arg)
                    }
                }
            }

            Text {
                x: 16
                width: parent.width - 32
                topPadding: 6
                visible: root.canReceive
                text: "Changing this while receiving restarts the window from now."
                wrapMode: Text.WordWrap
                color: root.pal.inkSub
                font.family: root.t.fontFamily
                font.pixelSize: 11
                font.weight: Font.DemiBold
            }

            // ===== who can see us =====
            SectionHead {
                theme: root.t
                pal: root.pal
                label: "Who can see this computer"
                value: root.m.visibility === "contacts" ? "contacts only" : "everyone"
            }

            Row {
                x: 12
                spacing: 6

                KeyCap {
                    theme: root.t
                    pal: root.pal
                    icon: "groups"
                    text: "Everyone"
                    lit: root.m.visibility !== "contacts"
                    onClicked: root.svc.setVisibility("everyone")
                }

                KeyCap {
                    theme: root.t
                    pal: root.pal
                    icon: "person"
                    text: "Contacts"
                    lit: root.m.visibility === "contacts"
                    onClicked: {
                        root.svc.setVisibility("contacts")
                        root.svc.refreshSenders()
                    }
                }
            }

            // name
            Item {
                x: 12
                width: parent.width - 24
                height: 40

                Rectangle {
                    x: 0
                    y: 6
                    width: parent.width - nameKey.width - 8
                    height: 32
                    radius: 9
                    color: root.pal.surface
                    border.width: 2
                    border.color: nameField.activeFocus ? root.t.colBorder : root.pal.line

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 9
                        anchors.verticalCenter: parent.verticalCenter
                        visible: root.nameDraft === "" && !nameField.activeFocus
                        text: "Name nearby devices see"
                        color: root.pal.inkSub
                        font.family: root.t.fontFamily
                        font.pixelSize: 12
                    }

                    TextInput {
                        id: nameField
                        anchors.fill: parent
                        anchors.leftMargin: 9
                        anchors.rightMargin: 9
                        verticalAlignment: TextInput.AlignVCenter
                        clip: true
                        selectByMouse: true
                        activeFocusOnPress: true
                        text: root.nameDraft
                        color: root.t.ink
                        font.family: root.t.fontFamily
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        onTextEdited: root.nameDraft = text
                        onAccepted: root.renameNow()

                        Keys.onEscapePressed: {
                            root.setNameDraft(root.m.name)
                            root.host.popup.close()
                        }
                    }
                }

                KeyCap {
                    id: nameKey
                    theme: root.t
                    pal: root.pal
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "check"
                    onClicked: root.renameNow()
                }
            }

            // folder
            Item {
                x: 12
                width: parent.width - 24
                height: 42

                Icon {
                    id: folderIcon
                    theme: root.t
                    x: 4
                    anchors.verticalCenter: parent.verticalCenter
                    name: "folder"
                    size: 16
                    color: root.pal.inkSub
                }

                Text {
                    anchors.left: folderIcon.right
                    anchors.leftMargin: 8
                    anchors.right: dirKey.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    elide: Text.ElideMiddle
                    text: root.m.dir !== "" ? root.m.dir : "Downloads"
                    color: root.pal.inkSub
                    font.family: root.t.fontFamily
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                }

                KeyCap {
                    id: dirKey
                    theme: root.t
                    pal: root.pal
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "folder_open"
                    text: "Choose"
                    onClicked: root.svc.pickDir()
                }
            }

            // sound
            Item {
                x: 12
                width: parent.width - 24
                height: 38

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 4
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Play a sound when a file arrives"
                    color: root.pal.ink
                    font.family: root.t.fontFamily
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                }

                Toggle {
                    theme: root.t
                    pal: root.pal
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    checked: root.m.sound
                    onToggled: root.svc.setSound(!root.m.sound)
                }
            }

            // ===== known senders =====
            Column {
                width: parent.width
                visible: root.m.visibility === "contacts"
                spacing: 3

                SectionHead {
                    theme: root.t
                    pal: root.pal
                    label: "Known senders"
                    value: root.svc ? root.svc.sendersList.length + " saved" : ""
                }

                Repeater {
                    model: root.svc ? root.svc.sendersList.slice(0, 6) : []

                    delegate: Item {
                        required property var modelData
                        x: 16
                        width: col.width - 32
                        height: 31

                        Text {
                            anchors.left: parent.left
                            anchors.right: removeKey.left
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            elide: Text.ElideRight
                            text: modelData
                            color: root.pal.ink
                            font.family: root.t.fontFamily
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                        }

                        KeyCap {
                            id: removeKey
                            theme: root.t
                            pal: root.pal
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            icon: "close"
                            onClicked: root.svc.removeSender(modelData)
                        }
                    }
                }

                Text {
                    x: 16
                    visible: root.svc && root.svc.sendersList.length > 6
                    text: "+" + (root.svc.sendersList.length - 6) + " more; manage with omdrop senders"
                    color: root.pal.inkSub
                    font.family: root.t.fontFamily
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                }

                Item {
                    x: 12
                    width: col.width - 24
                    height: 40

                    Rectangle {
                        x: 0
                        y: 5
                        width: parent.width - addKey.width - 8
                        height: 31
                        radius: 9
                        color: root.pal.surface
                        border.width: 2
                        border.color: senderField.activeFocus ? root.t.colBorder : root.pal.line

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 9
                            anchors.verticalCenter: parent.verticalCenter
                            visible: root.senderDraft === "" && !senderField.activeFocus
                            text: "Apple ID email or phone number"
                            color: root.pal.inkSub
                            font.family: root.t.fontFamily
                            font.pixelSize: 12
                        }

                        TextInput {
                            id: senderField
                            anchors.fill: parent
                            anchors.leftMargin: 9
                            anchors.rightMargin: 9
                            verticalAlignment: TextInput.AlignVCenter
                            clip: true
                            selectByMouse: true
                            activeFocusOnPress: true
                            text: root.senderDraft
                            color: root.t.ink
                            font.family: root.t.fontFamily
                            font.pixelSize: 12
                            Keys.onTabPressed: nameField.forceActiveFocus()
                            onTextEdited: root.senderDraft = text
                            onAccepted: root.addSenderNow()
                        }
                    }

                    KeyCap {
                        id: addKey
                        theme: root.t
                        pal: root.pal
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        icon: "add"
                        onClicked: root.addSenderNow()
                    }
                }

                Text {
                    x: 16
                    width: col.width - 32
                    visible: root.svc && root.svc.sendersError !== ""
                    wrapMode: Text.WordWrap
                    text: root.svc ? root.svc.sendersError : ""
                    color: root.t.warnFill
                    font.family: root.t.fontFamily
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                }

                Item { width: 1; height: 4 }
            }

            // ===== nearby =====
            SectionHead {
                theme: root.t
                pal: root.pal
                label: "Nearby"
                value: !root.canReceive ? "off"
                    : !root.svc || !root.svc.scanning ? "waiting for the radio"
                    : root.peers.length === 0 ? "nothing yet"
                    : root.svc && !root.svc.namesResolved ? "learning names…"
                    : root.peers.length + " seen"
            }

            Text {
                x: 16
                width: parent.width - 32
                visible: !root.canReceive
                topPadding: 2
                bottomPadding: 4
                wrapMode: Text.WordWrap
                text: "Turn Omdrop on to see nearby Apple devices. On an iPhone, the AirDrop sheet has to be open."
                color: root.pal.inkSub
                font.family: root.t.fontFamily
                font.pixelSize: 12
                font.weight: Font.DemiBold
                lineHeight: 1.25
            }

            Text {
                x: 16
                width: parent.width - 32
                visible: root.canReceive && root.svc && root.svc.scanning && root.peers.length === 0
                topPadding: 2
                bottomPadding: 4
                wrapMode: Text.WordWrap
                text: "Nothing nearby yet. On an iPhone, the AirDrop sheet has to be open."
                color: root.pal.inkSub
                font.family: root.t.fontFamily
                font.pixelSize: 12
                font.weight: Font.DemiBold
                lineHeight: 1.25
            }

            Repeater {
                model: root.canReceive ? root.peers : []

                delegate: PeerRow {
                    required property var modelData
                    width: col.width
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

            // ===== received links =====
            SectionHead {
                visible: links.count > 0
                theme: root.t
                pal: root.pal
                label: "Links"
                value: links.count === 1 ? "1 received" : links.count + " received"
            }

            Repeater {
                model: Math.min(links.count, root.linkLimit)

                delegate: Item {
                    id: linkRow
                    required property int index

                    readonly property string fileName: links.get(index, "fileName") || ""
                    readonly property string filePath: links.get(index, "filePath") || ""
                    property string url: ""

                    x: 12
                    width: col.width - 24
                    height: 36

                    FileView {
                        id: linkFile
                        path: linkRow.filePath
                        printErrors: false
                        onLoaded: linkRow.url = O.linkUrl(text(), linkRow.fileName)
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: 9
                        color: linkArea.containsMouse ? root.pal.surfaceHover : "transparent"
                    }

                    MouseArea {
                        id: linkArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.svc.openLink(linkRow.filePath)
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.right: openKey.left
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        elide: Text.ElideMiddle
                        text: linkRow.url !== "" ? linkRow.url : O.linkLabel(linkRow.fileName)
                        textFormat: Text.PlainText
                        color: root.pal.ink
                        font.family: root.t.fontFamily
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                    }

                    KeyCap {
                        id: openKey
                        theme: root.t
                        pal: root.pal
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        icon: "open_in_new"
                        text: "Open"
                        onClicked: root.svc.openLink(linkRow.filePath)
                    }
                }
            }

            Text {
                x: 16
                width: parent.width - 32
                visible: links.count > root.linkLimit
                text: "+" + (links.count - root.linkLimit) + " more in " + root.m.dir
                elide: Text.ElideMiddle
                color: root.pal.inkSub
                font.family: root.t.fontFamily
                font.pixelSize: 11
                font.weight: Font.DemiBold
            }

            // ===== footer =====
            Item {
                width: parent.width
                height: 40

                Text {
                    x: 16
                    anchors.verticalCenter: parent.verticalCenter
                    text: O.checkedText(root.svc ? root.svc.checkedAt : 0, root.now)
                    color: root.pal.inkSub
                    font.family: root.t.fontFamily
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                }

                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.svc && root.svc.busy
                    text: root.svc ? root.svc.busyText + "…" : ""
                    color: root.pal.inkSub
                    font.family: root.t.fontFamily
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                }
            }
        }
    }
}
