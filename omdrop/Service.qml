import QtQuick
import Quickshell
import Quickshell.Io
import "lib/Omdrop.js" as O

// The one place that runs `omdrop` (SekaiPop's plugin service, docs/PLUGINS.md there): the bar
// entry on every monitor, the popup and the widget all read `model` from here, so they agree and
// one status call feeds them all.
//
// `omdrop status --json` is the source of truth: whether receiving is on, whether the radio says
// anyone can see us, the countdown, the name, the audience. It asks only while something shows it
// (host.working): every 15 s for the bar alone, at "Check every" while the popup or widget is up,
// and sooner while the radio is still coming up.
//
// Turning receiving on and off needs root for the radio, so this runs the command rather than
// doing it itself; errors are the command's own sentences, shown as they are.
QtObject {
    id: root

    required property var host

    readonly property string cli: "omdrop"

    // O.model(): { state, message, receiving, visible, remaining, name, dir, mode, reason,
    // rxProven, sound, visibility, senders }. "off"/"missing" until the first answer.
    property var model: O.emptyModel("off")
    property real checkedAt: 0
    property real now: Date.now()

    // The last peer listing, and the names learnt so far, keyed by address. The names are
    // kept in a small cache file, so a radio restart does not send every row back to an address.
    property var peers: []
    property var peerNames: ({})
    property bool namesResolved: false
    readonly property string namesDir:
        (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state"))
        + "/sekaipop/plugins"
    property string namesPath: ""

    // `omdrop doctor --json`: what is in the way before this computer can receive.
    property var doctor: ({ ready: true, missing: [], offers: [] })
    property real doctorAt: 0

    // A command the user started (turning on, renaming, choosing a folder).
    property bool busy: false
    property string busyText: ""
    property string lastError: ""

    // The Contacts Only list, as stored.
    property var sendersList: []
    property string sendersError: ""

    // One send at a time, kept here so it survives the popup closing for the file chooser.
    property string sendingTo: ""
    property string sendingName: ""
    property string sendStatus: ""
    property string sendingFile: ""
    property bool sendChosen: false
    property bool sendCancelled: false
    property bool sendFailed: false
    property bool sendDone: false
    readonly property bool sendActive: root.sendProc.running && root.sendChosen

    readonly property var wanted: root.host.wanted
    readonly property bool looking: root.wanted.indexOf("popup") >= 0 || root.wanted.indexOf("widget") >= 0
    // Peers can only be heard while a window is open and proven visible.
    readonly property bool scanning: root.looking && root.model.state === "on"

    readonly property string windowValue: O.windowArg(root.host.settings.window)

    property bool statusStale: false

    function applyStatus(text) {
        const t = Date.now()
        const m = O.model(text)
        root.model = m
        root.checkedAt = t
        root.now = t
        if (m.state !== "on") {
            root.peers = []
            root.namesResolved = false
        }
        if (m.state === "error" || (m.receiving && m.visible === null))
            root.askDoctor()
    }

    function refresh() {
        if (root.statusProc.running)
            root.statusStale = true
        else
            root.statusProc.running = true
    }

    property Process statusProc: Process {
        command: ["sh", "-c", "command -v omdrop >/dev/null 2>&1 || { echo " + O.MISSING_MARK
            + "; exit 0; }; exec omdrop status --json 2>&1"]
        stdout: StdioCollector {
            onStreamFinished: if (!root.statusStale) root.applyStatus(text)
        }
        onExited: {
            if (root.statusStale) {
                root.statusStale = false
                root.statusProc.running = true
            }
        }
    }

    property Timer poll: Timer {
        running: root.host.working
        repeat: true
        triggeredOnStart: true
        interval: O.pollMs(root.host.wanted, root.host.settings.checkSeconds, root.model.state)
        onTriggered: root.refresh()
    }

    property Timer clock: Timer {
        running: root.looking
        repeat: true
        triggeredOnStart: true
        interval: 1000
        onTriggered: root.now = Date.now()
    }

    onLookingChanged: {
        if (root.looking)
            root.refresh()
    }

    // Opening the popup asks the radio at once, not at the bar's next quarter minute.
    Component.onCompleted: {
        root.mkdirProc.running = true
        root.refresh()
    }

    // ===== device names =====
    property Process mkdirProc: Process {
        command: ["mkdir", "-p", "-m", "700", root.namesDir]
        onExited: {
            root.namesPath = root.namesDir + "/omdrop-device-names.json"
            if (Object.keys(root.peerNames).length > 0)
                root.saveNames()
        }
    }

    property FileView namesFile: FileView {
        path: root.namesPath
        printErrors: false
        onLoaded: {
            const saved = O.readNames(text())
            const known = O.mergeNames(saved, root.peerNames)
            if (Object.keys(known).length > 0) {
                root.peerNames = known
                root.peers = O.mergePeers(root.peers, known)
            }
        }
    }

    function saveNames() {
        if (root.namesPath !== "")
            root.namesSave.restart()
    }

    property Timer namesSave: Timer {
        interval: 250
        onTriggered: root.namesFile.setText(JSON.stringify(root.peerNames))
    }

    // ===== doctor =====
    function askDoctor() {
        if (root.doctorProc.running || Date.now() - root.doctorAt < 15000)
            return
        root.doctorAt = Date.now()
        root.doctorProc.running = true
    }

    property Process doctorProc: Process {
        command: [root.cli, "doctor", "--json"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.doctor = O.doctorModel(text)
        }
    }

    // ===== receiving =====
    function toggle() {
        if (root.busy)
            return
        root.busy = true
        root.busyText = root.model.receiving ? "Turning off" : "Turning on"
        root.lastError = ""
        root.toggleProc.command = root.model.receiving
            ? [root.cli, "off"]
            : [root.cli, "on", root.windowValue]
        root.toggleProc.running = true
    }

    // Moving the chooser during a live window resets that window to the new choice, from now.
    function chooseWindow(arg) {
        const a = O.windowArg(arg)
        root.host.setSetting("window", a)
        if (!root.model.receiving) {
            root.busyText = ""
            return
        }
        if (root.busy)
            return
        root.busy = true
        root.busyText = "Updating window"
        root.lastError = ""
        root.rescheduleProc.command = [root.cli, "on", a]
        root.rescheduleProc.running = true
    }

    property Process toggleProc: Process {
        stderr: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.lastError = text.trim()
        }
        onExited: function (code) {
            root.busy = false
            root.busyText = ""
            if (code === 0)
                root.lastError = ""
            root.refresh()
        }
    }

    property Process rescheduleProc: Process {
        stderr: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.lastError = text.trim()
        }
        onExited: function (code) {
            root.busy = false
            root.busyText = ""
            if (code === 0)
                root.lastError = ""
            root.refresh()
        }
    }

    // The CLI validates names and folders; its message is the one shown.
    function rename(value) {
        const name = String(value || "").trim()
        if (name === "" || name === root.model.name || root.nameProc.running)
            return
        root.lastError = ""
        root.nameProc.command = [root.cli, "name", name]
        root.nameProc.running = true
    }

    property Process nameProc: Process {
        stderr: StdioCollector {
            waitForEnd: true
            onStreamFinished: if (text.trim() !== "") root.lastError = text.trim()
        }
        onExited: function (code) {
            if (code === 0)
                root.lastError = ""
            root.refresh()
        }
    }

    // The folder is chosen in a file dialog, never typed.
    function pickDir() {
        if (root.dirProc.running)
            return
        root.lastError = ""
        root.dirProc.running = true
    }

    property Process dirProc: Process {
        command: [root.cli, "dir", "--pick"]
        stderr: StdioCollector {
            waitForEnd: true
            onStreamFinished: if (text.trim() !== "") root.lastError = text.trim()
        }
        onExited: {
            root.refresh()
        }
    }

    function setVisibility(mode) {
        if (mode === root.model.visibility || root.audienceProc.running)
            return
        root.lastError = ""
        root.audienceProc.command = [root.cli, "visibility", mode]
        root.audienceProc.running = true
    }

    property Process audienceProc: Process {
        stderr: StdioCollector {
            waitForEnd: true
            onStreamFinished: if (text.trim() !== "") root.lastError = text.trim()
        }
        onExited: function (code) {
            if (code === 0)
                root.lastError = ""
            root.refresh()
        }
    }

    function setSound(on) {
        if (root.soundProc.running)
            return
        root.soundProc.command = [root.cli, "sound", on ? "on" : "off"]
        root.soundProc.running = true
    }

    property Process soundProc: Process {
        onExited: root.refresh()
    }

    // ===== known senders (Contacts Only) =====
    function refreshSenders() {
        if (!root.sendersListProc.running)
            root.sendersListProc.running = true
    }

    property Process sendersListProc: Process {
        command: [root.cli, "senders", "list", "--json"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                try {
                    const list = JSON.parse(text)
                    root.sendersList = Array.isArray(list) ? list.filter(x => typeof x === "string") : []
                } catch (e) {
                    root.sendersList = []
                }
            }
        }
    }

    function addSender(id) {
        const who = String(id || "").trim()
        if (who === "" || root.sendersEditProc.running)
            return
        root.sendersError = ""
        root.sendersEditProc.command = [root.cli, "senders", "add", who]
        root.sendersEditProc.running = true
    }

    function removeSender(id) {
        if (root.sendersEditProc.running)
            return
        root.sendersError = ""
        root.sendersEditProc.command = [root.cli, "senders", "remove", id]
        root.sendersEditProc.running = true
    }

    property Process sendersEditProc: Process {
        stderr: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.sendersError = text.trim().replace(/^omdrop: /, "")
        }
        onExited: function (code) {
            if (code === 0)
                root.sendersError = ""
            root.refreshSenders()
            root.refresh()
        }
    }

    // ===== nearby devices =====
    property Process peersProc: Process {
        command: [root.cli, "peers", "--json"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                const list = O.parsePeers(text)
                if (list === null)
                    return
                let known = root.peerNames
                for (let i = 0; i < list.length; i++) {
                    if (list[i].name !== "") {
                        known = O.rememberName(known, list[i].mac, list[i].name)
                        root.namesResolved = true
                    }
                }
                if (known !== root.peerNames) {
                    root.peerNames = known
                    root.saveNames()
                }
                root.peers = O.mergePeers(list, root.peerNames)
            }
        }
    }

    property Timer peersPoll: Timer {
        running: root.scanning
        repeat: true
        triggeredOnStart: true
        interval: 2000
        onTriggered: if (!root.peersProc.running) root.peersProc.running = true
    }

    property Process namesProc: Process {
        command: [root.cli, "peers", "--json", "-n", "--stream"]
        property double startedAt: 0
        onStarted: startedAt = Date.now()
        stdout: SplitParser {
            onRead: function (line) {
                try {
                    const p = O.normalizePeer(JSON.parse(line))
                    if (!p || p.name === "")
                        return
                    if (!root.peers.some(q => q.mac === p.mac))
                        return
                    root.peerNames = O.rememberName(root.peerNames, p.mac, p.name)
                    root.namesResolved = true
                    root.peers = O.mergePeers(root.peers, root.peerNames)
                    root.saveNames()
                } catch (e) {
                    // a line that is not a peer is not a name
                }
            }
        }
        onExited: {
            root.namesResolved = true
            if (!root.scanning)
                return
            // A lookup that fails at once would otherwise restart in a tight loop.
            const quick = Date.now() - startedAt < 5000
            root.namesAgain.interval = quick ? 10000 : 60000
            root.namesAgain.restart()
        }
    }

    property Timer namesAgain: Timer {
        onTriggered: if (root.scanning && !root.namesProc.running) root.namesProc.running = true
    }

    onScanningChanged: {
        if (root.scanning) {
            root.namesAgain.interval = 500
            root.namesAgain.restart()
        } else {
            root.namesAgain.stop()
            if (root.namesProc.running)
                root.namesProc.signal(15)
        }
    }

    // ===== sending =====
    function sendTo(mac) {
        if (root.sendProc.running || !mac)
            return
        const found = root.peers.filter(p => p.mac === mac)
        root.sendingTo = mac
        root.sendingName = found.length > 0 ? found[0].name : ""
        root.sendingFile = ""
        root.sendStatus = "Choose files…"
        root.sendChosen = false
        root.sendCancelled = false
        root.sendFailed = false
        root.sendDone = false
        root.sendProc.command = [root.cli, "send", "--pick", "--to", mac]
        root.sendProc.running = true
    }

    function cancelSend() {
        if (!root.sendProc.running)
            return
        root.sendCancelled = true
        root.sendStatus = "Cancelling…"
        root.sendProc.signal(15)
    }

    function dismissSend() {
        if (root.sendProc.running)
            return
        root.sendingTo = ""
        root.sendStatus = ""
        root.sendFailed = false
        root.sendDone = false
        root.sendingFile = ""
    }

    property Process sendProc: Process {
        stdout: SplitParser {
            onRead: function (line) {
                line = line.trim()
                if (line === "")
                    return
                if (!root.sendChosen) {
                    root.sendChosen = true
                    root.sendStatus = line
                }
                const chosen = /^Preparing (.*)\.\.\.$/.exec(line)
                if (chosen)
                    root.sendingFile = chosen[1]
                root.sendStatus = line
            }
        }
        stderr: SplitParser {
            onRead: function (line) {
                line = line.trim()
                if (line === "")
                    return
                const sending = /^sending (.*) to \S+ at /.exec(line)
                if (sending || /^waiting up to \d+s for .* to start listening/.test(line)) {
                    const file = root.sendingFile || (sending ? sending[1].replace(/^.*\//, "") : "the file")
                    line = "Sending " + file + " to "
                        + (root.peerNames[root.sendingTo] || root.sendingName || root.sendingTo) + "…"
                }
                root.sendStatus = line
            }
        }
        onExited: function (code) {
            const cancelled = root.sendCancelled
                || (code !== 0 && !root.sendChosen && root.sendStatus === "Choose files…")
            root.sendCancelled = false
            if (cancelled) {
                root.sendingTo = ""
                root.sendStatus = ""
                return
            }
            root.sendFailed = code !== 0
            root.sendDone = code === 0
            if (root.sendDone)
                root.sendStatus = "Sent"
            root.refresh()
        }
    }

    // ===== shared helpers =====
    function copy(text) {
        if (text)
            Quickshell.execDetached(["sh", "-c", "printf '%s' \"$1\" | wl-copy", "sh", String(text)])
    }

    // Received links go through omdrop's own web-only gate, whichever way they are opened.
    function openLink(path) {
        if (path)
            Quickshell.execDetached([root.cli, "open-link", String(path)])
    }
}
