import QtQuick
import QtQuick.Shapes
import Quickshell.Io
import "Omdrop.js" as O

// The radar Omdrop draws: every learned device sits on a ring by its address (fixed, so it
// doesn't jump when the signal changes) and by its signal (closer is stronger). Named devices
// get their name; unnamed ones are dots until `omdrop peers -n` learns them.
//
// The sweep only runs while we are really advertising (`scanning`), so a still radar means a
// still radio rather than a dropped frame.
Item {
    id: root

    required property var theme
    property var peers: []
    property bool scanning: false
    property bool interactive: true
    property bool labels: true
    property bool showEmptyText: true
    property string soundDir: ""
    property bool muted: true

    signal sendRequested(string mac)

    readonly property real radius: Math.max(10, Math.min(width, height) / 2 - 18)
    readonly property color ink: root.theme.ink
    readonly property color dim: root.theme.inkSub
    readonly property bool audible: root.visible && root.scanning && !root.muted
        && root.soundDir !== ""

    property real previousSweepAngle: -1
    property var namedPeers: ({})

    readonly property var voices: [voiceOne, voiceTwo, voiceThree]

    function stopSounds() {
        for (var i = 0; i < root.voices.length; i++)
            root.voices[i].running = false
    }

    function playSound(filename, volume) {
        if (!root.audible)
            return
        for (var i = 0; i < root.voices.length; i++) {
            var voice = root.voices[i]
            if (voice.running)
                continue
            voice.command = ["/bin/sh", "-c",
                'if command -v pw-play >/dev/null 2>&1; then exec pw-play --volume "$2" "$1"; elif command -v paplay >/dev/null 2>&1; then exec paplay --volume "$3" "$1"; fi',
                "omdrop-sound", root.soundDir + "/" + filename, String(volume),
                String(Math.round(volume * 65536))]
            voice.running = true
            return
        }
    }

    // A blip when a name arrives (the same cue Omdrop gives), and the quieter contact pings as
    // the sweep crosses a named device. The three voices drop a crossing rather than queue it.
    function reconcileSounds() {
        var list = root.peers || []
        var named = ({})
        var fresh = false
        for (var i = 0; i < list.length; i++) {
            var p = list[i]
            if (!p || typeof p.mac !== "string" || typeof p.name !== "string" || p.name === "")
                continue
            named[p.mac] = true
            if (!root.namedPeers[p.mac])
                fresh = true
        }
        root.namedPeers = named
        if (fresh)
            root.playSound("blip.wav", 0.55)
    }

    function advanceSweep(current) {
        var previous = root.previousSweepAngle
        root.previousSweepAngle = current
        if (!root.audible || previous < 0)
            return
        var travelled = (current - previous + 360) % 360
        if (travelled <= 0)
            return
        var list = root.peers || []
        for (var i = 0; i < list.length; i++) {
            var p = list[i]
            if (!p || typeof p.name !== "string" || p.name === "")
                continue
            var distance = (O.angleFor(p.mac) - previous + 360) % 360
            if (distance > 0 && distance <= travelled) {
                var strength = O.strength(p.rssi)
                root.playSound("contact-" + (1 + Math.round(strength * 4)) + ".wav",
                    0.55 + 0.45 * strength)
            }
        }
    }

    onPeersChanged: root.reconcileSounds()
    onScanningChanged: {
        root.previousSweepAngle = -1
        if (!root.scanning) {
            root.namedPeers = ({})
            root.stopSounds()
        }
    }
    onMutedChanged: if (root.muted) root.stopSounds()
    onVisibleChanged: if (!root.visible) root.stopSounds()

    Process { id: voiceOne }
    Process { id: voiceTwo }
    Process { id: voiceThree }

    implicitWidth: 250
    implicitHeight: 250

    // rings and crosshair
    Repeater {
        model: [0.34, 0.67, 1.0]

        delegate: Rectangle {
            required property real modelData
            anchors.centerIn: parent
            width: root.radius * 2 * modelData
            height: width
            radius: width / 2
            color: "transparent"
            border.width: modelData === 1 ? 2.5 : 1.5
            border.color: root.ink
            opacity: modelData === 1 ? 0.5 : 0.22
        }
    }

    Rectangle {
        anchors.centerIn: parent
        width: root.radius * 2
        height: 1.5
        color: root.ink
        opacity: 0.18
    }

    Rectangle {
        anchors.centerIn: parent
        width: 1.5
        height: root.radius * 2
        color: root.ink
        opacity: 0.18
    }

    // the sweep: a wide faint quarter and a brighter leading edge, turning once every 3.6 s
    Item {
        id: sweep
        anchors.centerIn: parent
        width: root.radius * 2
        height: root.radius * 2
        visible: root.scanning

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeWidth: 0
                fillGradient: ConicalGradient {
                    centerX: sweep.width / 2
                    centerY: sweep.height / 2
                    angle: 0
                    GradientStop { position: 0.0; color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.22) }
                    GradientStop { position: 0.25; color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.0) }
                    GradientStop { position: 1.0; color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.0) }
                }
                startX: sweep.width / 2
                startY: sweep.height / 2
                PathLine { x: sweep.width / 2; y: 0 }
                PathArc {
                    x: sweep.width / 2
                    y: sweep.height
                    radiusX: sweep.width / 2
                    radiusY: sweep.height / 2
                    direction: PathArc.Clockwise
                }
                PathLine { x: sweep.width / 2; y: sweep.height / 2 }
            }
        }

        RotationAnimation on rotation {
            running: root.scanning && root.visible
            from: 0
            to: 360
            duration: 3600
            loops: Animation.Infinite
        }

        onRotationChanged: root.advanceSweep(rotation)
    }

    // the centre: this machine
    Rectangle {
        anchors.centerIn: parent
        width: 8
        height: 8
        radius: 4
        color: root.ink
    }

    Text {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: 35
        visible: root.showEmptyText && root.peers.length === 0
        text: root.scanning ? "Nothing nearby yet" : "Not scanning"
        color: root.dim
        font.family: root.theme.fontFamily
        font.pixelSize: 12
        font.weight: Font.DemiBold
    }

    // devices
    Repeater {
        model: root.peers

        delegate: Item {
            id: dot
            required property var modelData
            readonly property string mac: modelData.mac
            readonly property string name: modelData.name
            readonly property real a: O.angleFor(modelData.mac)
            readonly property real frac: 0.94 - 0.78 * O.strength(modelData.rssi)
            readonly property bool labelRight: Math.sin(a) > 0
            readonly property color dotColor: labelRight ? root.ink : root.dim

            x: root.width / 2 + Math.sin(a) * root.radius * frac - 6
            y: root.height / 2 - Math.cos(a) * root.radius * frac - 6
            width: 12
            height: 12

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: dot.dotColor
            }

            Text {
                id: label
                visible: root.labels && dot.name !== ""
                x: dot.labelRight ? 10 : -implicitWidth - 10
                anchors.verticalCenter: parent.verticalCenter
                text: dot.name
                textFormat: Text.PlainText
                color: root.ink
                font.family: root.theme.fontFamily
                font.pixelSize: 11
                font.weight: Font.ExtraBold
                font.styleName: root.theme.fontStyleBold
            }

            MouseArea {
                anchors.fill: parent
                enabled: root.interactive
                cursorShape: Qt.PointingHandCursor
                onClicked: root.sendRequested(dot.mac)
            }

            MouseArea {
                visible: label.visible
                enabled: root.interactive
                x: label.x
                y: label.y
                width: label.width
                height: label.height
                cursorShape: Qt.PointingHandCursor
                onClicked: root.sendRequested(dot.mac)
            }
        }
    }
}
