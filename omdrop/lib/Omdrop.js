.pragma library

// Omdrop's rules, as pure functions on the JSON its command line already speaks. Every surface
// (the bar entry, the popup, the widget) draws from these, so they agree; the QML holds no logic
// of its own. Tested in node: tests/omdrop_unit.js.

// What Service.qml prints when `omdrop` is not on the shell's PATH.
var MISSING_MARK = "__omdrop_missing__"

// The shell's plugin interface calls these "states" in the bar's tip and the status chip.
//   on        receiving, and the radio says somebody can see us
//   waiting   receiving, but the radio is not advertising (a fault worth saying)
//   starting  receiving; the radio is coming up, or has no way to tell us
//   off       not receiving
//   missing   no `omdrop` command
//   error     the command answered with something that is not a status
var STATES = ["on", "off", "waiting", "starting", "missing", "error"]

var STATE_WORDS = {
    on: "Receiving",
    off: "Off",
    waiting: "Not visible",
    starting: "Starting",
    missing: "Not installed",
    error: "Not answering"
}

// The stops the window slider offers. The value is what `omdrop on` takes.
var WINDOW_STOPS = [
    { arg: "once", label: "One file", short: "One file" },
    { arg: "1m", label: "1 minute", short: "1 min" },
    { arg: "5m", label: "5 minutes", short: "5 min" },
    { arg: "10m", label: "10 minutes", short: "10 min" },
    { arg: "15m", label: "15 minutes", short: "15 min" },
    { arg: "30m", label: "30 minutes", short: "30 min" },
    { arg: "60m", label: "1 hour", short: "1 hour" },
    { arg: "forever", label: "Until turned off", short: "Until off" }
]

var WINDOW_ARGS = WINDOW_STOPS.map(function (s) { return s.arg })

function firstLine(text) {
    var lines = String(text || "").split("\n")
    for (var i = 0; i < lines.length; i++) {
        var l = lines[i].trim()
        if (l !== "")
            return l
    }
    return ""
}

// classify(output) -> { kind: "status", status } | { kind: "missing" } | { kind: "error", message }
// `output` is stdout and stderr together, so an error is read the same way as an answer.
function classify(output) {
    var text = String(output || "").trim()
    if (text.indexOf(MISSING_MARK) >= 0)
        return { kind: "missing" }
    var brace = text.indexOf("{")
    if (brace >= 0) {
        try {
            var s = JSON.parse(text.slice(brace))
            if (s && typeof s === "object" && typeof s.receiving === "boolean")
                return { kind: "status", status: s }
        } catch (e) {
            // not JSON: read the text as a message
        }
    }
    return { kind: "error", message: firstLine(text) || "omdrop said nothing" }
}

function emptyModel(state, message) {
    return {
        state: state || "error",
        message: message || "",
        receiving: false,
        visible: null,
        remaining: null,
        name: "",
        dir: "",
        mode: "off",
        reason: "",
        rxProven: false,
        sound: true,
        visibility: "everyone",
        senders: 0
    }
}

// model(output) -> everything the surfaces show, for one `omdrop status --json`.
function model(output) {
    var c = classify(output)
    if (c.kind !== "status")
        return emptyModel(c.kind, c.message)
    var s = c.status
    var receiving = s.receiving === true
    var visible = (s.visible === null || s.visible === undefined) ? null : s.visible === true
    var state = !receiving ? "off" : visible === true ? "on" : visible === false ? "waiting" : "starting"
    return {
        state: state,
        message: "",
        receiving: receiving,
        visible: visible,
        remaining: typeof s.remaining === "number" && isFinite(s.remaining) ? s.remaining : null,
        name: typeof s.name === "string" ? s.name : "",
        dir: typeof s.dir === "string" ? s.dir : "",
        mode: typeof s.mode === "string" && s.mode !== "" ? s.mode : "off",
        reason: typeof s.reason === "string" ? s.reason : "",
        rxProven: s.rx_proven === true,
        sound: s.sound !== false,
        visibility: s.visibility === "contacts" ? "contacts" : "everyone",
        senders: typeof s.senders === "number" && s.senders > 0 ? s.senders : 0
    }
}

// Why the radio says it is not visible, in words rather than a token.
function reasonText(m) {
    switch (m.reason) {
    case "no_awdl0":
        return "The AWDL interface is missing. The Wi-Fi driver needs loading."
    case "parked":
        return ""
    case "":
    case "ok":
    case "expired":
    case "stopped":
        return ""
    default:
        return m.visible === true ? "" : "The radio side reports: " + m.reason
    }
}

// "10:00", "1:02:03"; empty for no countdown.
function formatRemaining(sec) {
    if (typeof sec !== "number" || !isFinite(sec) || sec < 0)
        return ""
    var s = Math.floor(sec)
    var h = Math.floor(s / 3600)
    var m = Math.floor((s % 3600) / 60)
    var r = s % 60
    var pad = function (n) { return n < 10 ? "0" + n : String(n) }
    return h > 0 ? h + ":" + pad(m) + ":" + pad(r) : m + ":" + pad(r)
}

// The bar entry's words, next to its icon.
function entryText(m, iconOnly) {
    if (iconOnly)
        return ""
    if (m.state === "on")
        return m.remaining !== null && m.remaining > 0 ? formatRemaining(m.remaining) : "On"
    if (m.state === "waiting")
        return "Hidden"
    if (m.state === "starting")
        return ""
    if (m.state === "missing")
        return "Missing"
    if (m.state === "error")
        return "Error"
    return "Off"
}

function entryTip(m) {
    if (m.state === "missing")
        return "Omdrop: the omdrop command is not installed"
    if (m.state === "error")
        return "Omdrop: " + (m.message || "not answering")
    if (m.state === "off")
        return "Omdrop: off"
    if (m.state === "starting")
        return "Omdrop: waking the radio"
    if (m.state === "waiting")
        return "Omdrop: receiving, but nobody can see you yet"
    var left = formatRemaining(m.remaining)
    return "Omdrop: visible" + (left !== "" ? " for " + left : "") + " as " + (m.name || "this computer")
}

// The bar's status dot when the setting is "Icon only".
function entryDot(m) {
    if (m.state === "on")
        return "on"
    if (m.state === "waiting" || m.state === "starting")
        return "waiting"
    if (m.state === "error")
        return "error"
    return "off"
}

// The one sentence under the state in the popup and the widget.
function statusLine(m) {
    if (m.state === "missing")
        return "There is no omdrop command on the shell's PATH. Install Omdrop, then reload the shell."
    if (m.state === "error")
        return m.message || "omdrop did not answer."
    if (m.state === "off")
        return "Nearby Apple devices cannot see this computer."
    if (m.state === "starting")
        return m.visible === null
            ? "Receiving, but the radio half is missing, so nobody can see this computer."
            : "The radio takes a few seconds to come up."
    if (m.state === "waiting")
        return reasonText(m) || "The receiver is up, but nothing is advertising on the radio."
    return visibleText(m)
}

function visibleText(m) {
    var who = m.name !== "" ? "\"" + m.name + "\"" : "this computer"
    if (m.visibility === "contacts") {
        if (m.senders === 0)
            return "Your known-senders list is empty, so everyone is refused. Add people with: omdrop senders add EMAIL"
        return "Only your " + m.senders + (m.senders === 1 ? " known sender" : " known senders")
            + " should see " + who + " in AirDrop, after 10 seconds."
    }
    return "Nearby Apple devices should see " + who + " in AirDrop, after 10 seconds."
}

function detailText(m) {
    if (m.state === "on")
        return visibleText(m)
    return statusLine(m)
}

function isUrgent(m) {
    return m.state === "waiting" || m.state === "error"
        || (m.state === "on" && m.visibility === "contacts" && m.senders === 0)
}

// ---- the window chooser -------------------------------------------------------

function windowArg(value) {
    return WINDOW_ARGS.indexOf(value) >= 0 ? value : "10m"
}

function windowLabel(value) {
    return WINDOW_STOPS[WINDOW_ARGS.indexOf(windowArg(value))].label
}

function stopForRemaining(sec) {
    if (typeof sec !== "number" || sec < 0)
        return "once"
    var mins = sec / 60
    for (var i = 1; i < WINDOW_STOPS.length - 1; i++) {
        var n = parseInt(WINDOW_STOPS[i].arg, 10)
        if (n >= mins)
            return WINDOW_STOPS[i].arg
    }
    return "forever"
}

// What the chooser should light: the saved choice while off, what is running while on.
function activeWindow(m, saved) {
    if (m.state !== "on" && m.state !== "waiting" && m.state !== "starting")
        return windowArg(saved)
    if (m.mode === "once")
        return "once"
    if (m.mode === "forever")
        return "forever"
    if (m.mode === "timed" && m.remaining !== null && m.remaining > 0)
        return stopForRemaining(m.remaining)
    return windowArg(saved)
}

// ---- nearby devices -----------------------------------------------------------

var NAME_CACHE_MAX = 512

function cleanName(name) {
    if (typeof name !== "string")
        return ""
    var s = name.replace(/[\u0000-\u001f\u007f-\u009f\u200b-\u200f\u2028-\u202e\u2066-\u2069\ufeff]/g, "")
    s = s.trim()
    while (s.length > 0) {
        var code = s.charCodeAt(s.length - 1)
        if (code >= 0xd800 && code <= 0xdbff) {
            s = s.slice(0, -1)
            continue
        }
        break
    }
    return s.slice(0, 255)
}

function cleanMac(mac) {
    if (typeof mac !== "string")
        return ""
    var s = cleanName(mac).toLowerCase()
    return /^[0-9a-f:.-]{1,64}$/.test(s) ? s : ""
}

// The names learnt before, from the cache file. Anything unreadable is an empty cache, never
// an error; a damaged entry is dropped rather than allowed to reach a label.
function readNames(text) {
    var t = String(text || "").trim()
    if (t === "")
        return {}
    try {
        var saved = JSON.parse(t)
        if (!saved || typeof saved !== "object" || Array.isArray(saved))
            return {}
        var out = {}
        var count = 0
        var keys = Object.keys(saved)
        for (var i = 0; i < keys.length && count < NAME_CACHE_MAX; i++) {
            var mac = cleanMac(keys[i])
            var name = cleanName(saved[keys[i]])
            if (mac !== "" && name !== "") {
                out[mac] = name
                count++
            }
        }
        return out
    } catch (e) {
        return {}
    }
}

// One more name, with the oldest dropped once the cache is full. A fresh object, so QML sees
// the change.
function rememberName(names, mac, name, max) {
    var key = cleanMac(mac)
    var clean = cleanName(name)
    var out = {}
    if (names && typeof names === "object") {
        var keys = Object.keys(names)
        for (var i = 0; i < keys.length; i++) {
            var k = cleanMac(keys[i])
            var v = cleanName(names[keys[i]])
            if (k !== "" && v !== "")
                out[k] = v
        }
    }
    if (key === "" || clean === "")
        return out
    delete out[key]
    out[key] = clean
    var limit = typeof max === "number" && isFinite(max) && max > 0 ? Math.floor(max) : NAME_CACHE_MAX
    var all = Object.keys(out)
    for (var j = 0; j < all.length - limit; j++)
        delete out[all[j]]
    return out
}

function mergeNames(base, over) {
    var out = {}
    var a = base && typeof base === "object" ? base : {}
    var b = over && typeof over === "object" ? over : {}
    var keys = Object.keys(a).concat(Object.keys(b))
    for (var i = 0; i < keys.length; i++) {
        var mac = cleanMac(keys[i])
        var name = cleanName(b[keys[i]] !== undefined ? b[keys[i]] : a[keys[i]])
        if (mac !== "" && name !== "")
            out[mac] = name
    }
    return readNames(JSON.stringify(out))
}

function normalizePeer(p) {
    if (!p || typeof p !== "object" || typeof p.mac !== "string" || p.mac === "")
        return null
    var known = typeof p.rssi === "number" && isFinite(p.rssi)
    return {
        mac: p.mac.toLowerCase(),
        rssi: known ? p.rssi : null,
        name: cleanName(p.name)
    }
}

// parsePeers(output) -> array, or null when the command was not there.
function parsePeers(output) {
    var text = String(output || "").trim()
    if (text.indexOf(MISSING_MARK) >= 0)
        return null
    var bracket = text.indexOf("[")
    if (bracket < 0)
        return []
    try {
        var list = JSON.parse(text.slice(bracket))
        if (!Array.isArray(list))
            return []
        var out = []
        var seen = {}
        for (var i = 0; i < list.length; i++) {
            var p = normalizePeer(list[i])
            if (!p || seen[p.mac])
                continue
            seen[p.mac] = true
            out.push(p)
        }
        return out
    } catch (e) {
        return []
    }
}

function normalizePeers(list) {
    var out = []
    var seen = {}
    for (var i = 0; i < (list || []).length; i++) {
        var p = normalizePeer(list[i])
        if (!p || seen[p.mac])
            continue
        seen[p.mac] = true
        out.push(p)
    }
    return out
}

// Put every name learnt before on the peers still listed.
function mergePeers(list, names) {
    var out = normalizePeers(list)
    for (var i = 0; i < out.length; i++)
        if (out[i].name === "" && names && typeof names[out[i].mac] === "string")
            out[i].name = names[out[i].mac]
    return out
}

function namedPeers(peers) {
    return (peers || []).filter(function (p) { return p.name !== "" })
}

// Named devices first, then the strongest signal; address breaks a tie.
function sortedPeers(peers) {
    return (peers || []).slice().sort(function (a, b) {
        var an = a.name === "" ? 1 : 0, bn = b.name === "" ? 1 : 0
        if (an !== bn)
            return an - bn
        if (a.name !== b.name)
            return a.name.toLowerCase() < b.name.toLowerCase() ? -1 : 1
        var ar = a.rssi === null ? -999 : a.rssi, br = b.rssi === null ? -999 : b.rssi
        if (ar !== br)
            return br - ar
        return a.mac < b.mac ? -1 : a.mac > b.mac ? 1 : 0
    })
}

function peerLabel(p) {
    return p && p.name !== "" ? p.name : (p ? p.mac : "")
}

// 0..1: -90 dBm is the edge, -30 is right next to us. Null when the driver does not say.
function strength(rssi) {
    if (typeof rssi !== "number" || !isFinite(rssi))
        return 0
    return Math.max(0, Math.min(1, (rssi + 90) / 60))
}

function angleFor(mac) {
    var hash = 0
    var s = String(mac || "")
    for (var i = 0; i < s.length; i++)
        hash = (hash * 31 + s.charCodeAt(i)) >>> 0
    return hash % 360
}

function signalText(p) {
    return p && p.rssi !== null ? p.rssi + " dBm" : "signal unknown"
}

// The send row's bar: working, finished, failed, or not there at all.
function sendPhase(sending, done, failed) {
    if (sending)
        return "working"
    if (failed)
        return "failed"
    if (done)
        return "done"
    return "idle"
}

// ---- received links -----------------------------------------------------------

// A path as a file:// URL, so FolderListModel can watch it. Each segment is encoded, which keeps
// spaces, # and % out of the URL's syntax.
function fileUrl(path) {
    var p = String(path || "")
    if (p === "")
        return ""
    return "file://" + p.split("/").map(encodeURIComponent).join("/")
}

function linkLabel(fileName) {
    var s = String(fileName || "").replace(/\.(url|webloc)$/i, "").trim()
    return s === "" ? "Link" : s
}

// Whether a URL is a web page, the only kind omdrop opens. Mirrors the CLI's gate, so the popup
// never presents file:// or an app's custom scheme as a link it will open.
function webUrl(url) {
    var s = String(url || "").trim()
    if (!/^https?:\/\//i.test(s))
        return ""
    if (/[\u0000-\u0020\u007f]/.test(s))
        return ""
    var rest = s.replace(/^https?:\/\//i, "")
    return rest === "" || rest.charAt(0) === "/" ? "" : s
}

function iniUrl(body) {
    var lines = String(body || "").split(/\r?\n/)
    var inSection = false
    for (var i = 0; i < lines.length; i++) {
        var line = lines[i].replace(/\r$/, "")
        var header = /^\s*\[(.*)\]\s*$/.exec(line)
        if (header) {
            inSection = header[1].replace(/\s/g, "").toLowerCase() === "internetshortcut"
            continue
        }
        if (!inSection)
            continue
        var pair = /^\s*url\s*=\s*(.*)$/i.exec(line)
        if (pair)
            return pair[1].trim()
    }
    return ""
}

function xmlText(s) {
    return String(s || "").replace(/&(amp|lt|gt|quot|apos|#\d+|#x[0-9a-f]+);/gi, function (m, key) {
        var k = key.toLowerCase()
        if (k === "amp")
            return "&"
        if (k === "lt")
            return "<"
        if (k === "gt")
            return ">"
        if (k === "quot")
            return "\""
        if (k === "apos")
            return "'"
        var digits = k.slice(1)
        var code = digits.charAt(0) === "x" ? parseInt(digits.slice(1), 16) : parseInt(digits, 10)
        return code > 0 && code <= 0xffff ? String.fromCharCode(code) : m
    })
}

function plistUrl(body) {
    var m = /<key>\s*URL\s*<\/key>\s*<string>([\s\S]*?)<\/string>/i.exec(String(body || ""))
    return m ? xmlText(m[1]).trim() : ""
}

// linkUrl(text, fileName) -> the web link inside a received .url/.webloc, or "". Binary .webloc
// files cannot be read here; their row still opens through `omdrop open-link`, which can.
function linkUrl(text, fileName) {
    var name = String(fileName || "").toLowerCase()
    var body = String(text || "")
    if (/\.url$/.test(name))
        return webUrl(iniUrl(body))
    if (/\.webloc$/.test(name))
        return webUrl(plistUrl(body))
    return ""
}

// What a link row says: the URL when the file is readable, else the name the receiver gave it.
function linkTitle(text, fileName) {
    var url = linkUrl(text, fileName)
    return url !== "" ? url : linkLabel(fileName)
}

// ---- doctor -------------------------------------------------------------------

function doctorModel(output) {
    var text = String(output || "").trim()
    var empty = { ready: true, missing: [], offers: [] }
    var brace = text.indexOf("{")
    if (brace < 0)
        return empty
    try {
        var d = JSON.parse(text.slice(brace))
        if (!d || typeof d !== "object")
            return empty
        var rows = function (list) {
            var out = []
            for (var i = 0; i < (list || []).length; i++) {
                var r = list[i]
                if (r && typeof r.id === "string" && typeof r.say === "string")
                    out.push({ id: r.id, say: r.say })
            }
            return out
        }
        return { ready: d.ready === true, missing: rows(d.missing), offers: rows(d.offers) }
    } catch (e) {
        return empty
    }
}

function doctorText(doctor) {
    return doctor && doctor.missing && doctor.missing.length > 0 ? doctor.missing[0].say : ""
}

// "just now", "4 s ago", "2 min ago".
function checkedText(t, now) {
    if (!t)
        return "not checked yet"
    var s = Math.max(0, Math.floor((now - t) / 1000))
    if (s < 2)
        return "checked just now"
    if (s < 60)
        return "checked " + s + " s ago"
    if (s < 3600)
        return "checked " + Math.floor(s / 60) + " min ago"
    return "checked " + Math.floor(s / 3600) + " h ago"
}

// How often the service asks: at the user's pace while a popup or widget shows, slower for the
// bar alone, and sooner while the radio is still coming up.
function pollMs(wanted, checkSeconds, state) {
    var looking = (wanted || []).indexOf("popup") >= 0 || (wanted || []).indexOf("widget") >= 0
    if (!looking)
        return 15000
    if (state === "starting" || state === "waiting")
        return 3000
    var s = Number(checkSeconds)
    return (isFinite(s) && s >= 2 ? Math.min(60, Math.floor(s)) : 5) * 1000
}
