// Omdrop's rules (omdrop/lib/Omdrop.js), in node.
// Run: node --test tests/ (scripts/test.sh adds the coverage floor)
const { test } = require("node:test")
const assert = require("node:assert")
const load = require("./load")

const O = load("omdrop/lib/Omdrop.js", [
    "MISSING_MARK", "STATES", "STATE_WORDS", "WINDOW_STOPS", "WINDOW_ARGS",
    "firstLine", "classify", "emptyModel", "model", "reasonText", "formatRemaining",
    "entryText", "entryTip", "entryDot", "statusLine", "visibleText", "detailText", "isUrgent",
    "windowArg", "windowLabel", "stopForRemaining", "activeWindow",
    "cleanName", "normalizePeer", "parsePeers", "normalizePeers", "mergePeers", "namedPeers",
    "sortedPeers", "peerLabel", "strength", "angleFor", "signalText",
    "doctorModel", "doctorText", "checkedText", "pollMs"
])

const status = over => JSON.stringify(Object.assign({
    receiving: true,
    visible: true,
    remaining: 600,
    name: "Study Mac",
    dir: "/home/me/Downloads",
    mode: "timed",
    reason: "",
    rx_proven: true,
    sound: true,
    visibility: "everyone",
    senders: 0
}, over || {}))

test("classify: a status, a missing command, and anything else", () => {
    assert.strictEqual(O.classify(status()).kind, "status")
    assert.strictEqual(O.classify("warning: a line first\n" + status()).kind, "status")
    assert.strictEqual(O.classify(O.MISSING_MARK).kind, "missing")
    assert.deepStrictEqual(O.classify("\n  no such option\nmore"), { kind: "error", message: "no such option" })
    assert.deepStrictEqual(O.classify(""), { kind: "error", message: "omdrop said nothing" })
    assert.strictEqual(O.classify("{ not json").kind, "error")
    assert.strictEqual(O.classify('{"visible":true}').kind, "error", "receiving is required")
    assert.strictEqual(O.classify("garbage").kind, "error")
    assert.strictEqual(O.firstLine("\n\n  hi  \nbye"), "hi")
})

test("model: the states of the receiver and the radio", () => {
    const on = O.model(status())
    assert.strictEqual(on.state, "on")
    assert.strictEqual(on.receiving, true)
    assert.strictEqual(on.visible, true)
    assert.strictEqual(on.remaining, 600)
    assert.strictEqual(on.name, "Study Mac")
    assert.strictEqual(on.visibility, "everyone")
    assert.strictEqual(O.model(status({ receiving: false, visible: false })).state, "off")
    assert.strictEqual(O.model(status({ visible: false })).state, "waiting")
    assert.strictEqual(O.model(status({ visible: null })).state, "starting")
    assert.strictEqual(O.model(status({ visible: undefined })).state, "starting")
    assert.strictEqual(O.model(O.MISSING_MARK).state, "missing")
    assert.strictEqual(O.model("boom").state, "error")
    assert.strictEqual(O.model("boom").message, "boom")

    const odd = O.model(status({
        remaining: null, name: null, dir: null, mode: "", reason: null,
        rx_proven: "yes", sound: false, visibility: "contacts", senders: 0
    }))
    assert.deepStrictEqual([odd.remaining, odd.name, odd.dir, odd.mode, odd.reason],
        [null, "", "", "off", ""])
    assert.strictEqual(odd.rxProven, false)
    assert.strictEqual(odd.sound, false)
    assert.strictEqual(odd.visibility, "contacts")
    assert.strictEqual(odd.senders, 0)

    for (const s of O.STATES)
        assert.ok(O.STATE_WORDS[s], "the chip has a word for " + s)
})

test("reasonText names what the radio side said", () => {
    const r = x => O.reasonText(O.model(status({ visible: false, reason: x })))
    assert.match(r("no_awdl0"), /AWDL interface/)
    assert.strictEqual(r("parked"), "")
    assert.strictEqual(r(""), "")
    assert.strictEqual(r("ok"), "")
    assert.strictEqual(r("expired"), "")
    assert.strictEqual(r("stopped"), "")
    assert.match(r("radio-busy"), /radio-busy/)
    assert.strictEqual(O.reasonText(O.model(status({ reason: "radio-busy" }))), "", "visible: no fault to report")
})

test("formatRemaining and the bar's words", () => {
    assert.strictEqual(O.formatRemaining(600), "10:00")
    assert.strictEqual(O.formatRemaining(3723), "1:02:03")
    assert.strictEqual(O.formatRemaining(9), "0:09")
    assert.strictEqual(O.formatRemaining(-1), "")
    assert.strictEqual(O.formatRemaining(null), "")
    assert.strictEqual(O.formatRemaining("10"), "")

    const m = (over) => O.model(status(over))
    assert.strictEqual(O.entryText(m(), false), "10:00")
    assert.strictEqual(O.entryText(m({ remaining: null }), false), "On")
    assert.strictEqual(O.entryText(m(), true), "")
    assert.strictEqual(O.entryText(m({ receiving: false }), false), "Off")
    assert.strictEqual(O.entryText(m({ visible: false }), false), "Hidden")
    assert.strictEqual(O.entryText(m({ visible: null }), false), "")
    assert.strictEqual(O.entryText(O.model(O.MISSING_MARK), false), "Missing")
    assert.strictEqual(O.entryText(O.model("boom"), false), "Error")

    assert.match(O.entryTip(O.model(O.MISSING_MARK)), /not installed/)
    assert.match(O.entryTip(O.model("denied")), /denied/)
    assert.strictEqual(O.entryTip(m({ receiving: false })), "Omdrop: off")
    assert.match(O.entryTip(m({ visible: null })), /waking/)
    assert.match(O.entryTip(m({ visible: false })), /nobody can see/)
    assert.match(O.entryTip(m()), /visible for 10:00 as Study Mac/)
    assert.match(O.entryTip(m({ name: null, remaining: null })), /visible as this computer/)

    assert.strictEqual(O.entryDot(m()), "on")
    assert.strictEqual(O.entryDot(m({ visible: false })), "waiting")
    assert.strictEqual(O.entryDot(m({ visible: null })), "waiting")
    assert.strictEqual(O.entryDot(O.model("boom")), "error")
    assert.strictEqual(O.entryDot(m({ receiving: false })), "off")
})

test("the popup's sentence, and when it is a fault", () => {
    const m = (over) => O.model(status(over))
    assert.match(O.statusLine(O.model(O.MISSING_MARK)), /no omdrop command/)
    assert.strictEqual(O.statusLine(O.model("boom")), "boom")
    assert.strictEqual(O.statusLine(O.model("")), "omdrop said nothing")
    assert.match(O.statusLine(m({ receiving: false })), /cannot see/)
    assert.match(O.statusLine(m({ visible: null })), /radio half is missing/)
    assert.match(O.statusLine(m({ visible: null, reason: "no_awdl0" })), /radio half is missing/)
    assert.match(O.statusLine(m({ visible: true })), /should see/)
    assert.match(O.statusLine(m({ visible: false })), /nothing is advertising/)
    assert.match(O.statusLine(m({ visible: false, reason: "no_awdl0" })), /AWDL/)
    assert.match(O.statusLine(m()), /should see "Study Mac"/)
    assert.strictEqual(O.visibleText(m({ name: null })).includes("this computer"), true)
    assert.match(O.visibleText(m({ visibility: "contacts", senders: 0 })), /list is empty/)
    assert.match(O.visibleText(m({ visibility: "contacts", senders: 1 })), /1 known sender/)
    assert.match(O.visibleText(m({ visibility: "contacts", senders: 3 })), /3 known senders/)
    assert.strictEqual(O.detailText(m()), O.visibleText(m()))
    assert.strictEqual(O.detailText(m({ receiving: false })), O.statusLine(m({ receiving: false })))
    assert.strictEqual(O.isUrgent(m({ visible: false })), true)
    assert.strictEqual(O.isUrgent(O.model("boom")), true)
    assert.strictEqual(O.isUrgent(m({ visibility: "contacts", senders: 0 })), true)
    assert.strictEqual(O.isUrgent(m()), false)
})

test("the window chooser", () => {
    assert.deepStrictEqual(O.WINDOW_ARGS, ["once", "1m", "5m", "10m", "15m", "30m", "60m", "forever"])
    assert.strictEqual(O.windowArg("5m"), "5m")
    assert.strictEqual(O.windowArg("nonsense"), "10m")
    assert.strictEqual(O.windowArg(undefined), "10m")
    assert.strictEqual(O.windowLabel("5m"), "5 minutes")
    assert.strictEqual(O.windowLabel("nonsense"), "10 minutes")
    assert.strictEqual(O.stopForRemaining(30), "1m")
    assert.strictEqual(O.stopForRemaining(600), "10m")
    assert.strictEqual(O.stopForRemaining(3600), "60m")
    assert.strictEqual(O.stopForRemaining(99999), "forever")
    assert.strictEqual(O.stopForRemaining(-1), "once")
    assert.strictEqual(O.stopForRemaining(null), "once")

    const m = (over) => O.model(status(over))
    assert.strictEqual(O.activeWindow(m({ receiving: false }), "5m"), "5m")
    assert.strictEqual(O.activeWindow(m({ mode: "once" }), "5m"), "once")
    assert.strictEqual(O.activeWindow(m({ mode: "forever" }), "5m"), "forever")
    assert.strictEqual(O.activeWindow(m({ remaining: 200 }), "30m"), "5m")
    assert.strictEqual(O.activeWindow(m({ remaining: 0 }), "30m"), "30m")
    assert.strictEqual(O.activeWindow(m({ mode: "off" }), "30m"), "30m")
})

test("nearby devices: parsing, names, order", () => {
    const text = JSON.stringify([
        { mac: "AA:BB:CC:DD:EE:01", rssi: -40, name: "Jane's iPhone" },
        { mac: "aa:bb:cc:dd:ee:01", rssi: -70, name: "duplicate" },
        { mac: "AA:BB:CC:DD:EE:02", rssi: null, name: null },
        { mac: "", rssi: -50, name: "no address" },
        null
    ])
    const list = O.parsePeers("some line\n" + text)
    assert.strictEqual(list.length, 2)
    assert.deepStrictEqual(list[0], { mac: "aa:bb:cc:dd:ee:01", rssi: -40, name: "Jane's iPhone" })
    assert.deepStrictEqual(list[1], { mac: "aa:bb:cc:dd:ee:02", rssi: null, name: "" })
    assert.strictEqual(O.parsePeers(O.MISSING_MARK), null)
    assert.deepStrictEqual(O.parsePeers(""), [])
    assert.deepStrictEqual(O.parsePeers("no array here"), [])
    assert.deepStrictEqual(O.parsePeers("{bad"), [])
    assert.deepStrictEqual(O.parsePeers("[bad"), [])
    assert.deepStrictEqual(O.parsePeers('{"a":1}'), [])
    assert.deepStrictEqual(O.parsePeers("[1,2]"), [])
    assert.strictEqual(O.normalizePeer(null), null)
    assert.strictEqual(O.normalizePeer({ mac: "" }), null)
    assert.strictEqual(O.normalizePeer({ mac: "x", rssi: "loud" }).rssi, null)

    assert.strictEqual(O.cleanName("  Jane\u0000\u200b  "), "Jane")
    assert.strictEqual(O.cleanName(null), "")
    assert.strictEqual(O.cleanName("x".repeat(300)).length, 255)
    assert.strictEqual(O.cleanName("abc\uD83D"), "abc")

    const names = { "aa:bb:cc:dd:ee:02": "Front desk" }
    const merged = O.mergePeers(list, names)
    assert.strictEqual(merged[1].name, "Front desk")
    assert.strictEqual(O.mergePeers(null, null).length, 0)
    assert.strictEqual(O.mergePeers(list, null)[1].name, "")

    assert.deepStrictEqual(O.namedPeers(list).map(p => p.mac), ["aa:bb:cc:dd:ee:01"])
    assert.deepStrictEqual(O.sortedPeers([]), [])

    const sorted = O.sortedPeers([
        { mac: "03", rssi: null, name: "" },
        { mac: "01", rssi: -70, name: "Zed" },
        { mac: "02", rssi: -30, name: "amy" },
        { mac: "04", rssi: -20, name: "" }
    ])
    assert.deepStrictEqual(sorted.map(p => p.mac), ["02", "01", "04", "03"])
    const tie = O.sortedPeers([
        { mac: "b", rssi: -50, name: "same" },
        { mac: "a", rssi: -50, name: "same" }
    ])
    assert.deepStrictEqual(tie.map(p => p.mac), ["a", "b"])
    assert.strictEqual(O.peerLabel({ name: "Jane", mac: "x" }), "Jane")
    assert.strictEqual(O.peerLabel({ name: "", mac: "x" }), "x")
    assert.strictEqual(O.peerLabel(null), "")

    assert.strictEqual(O.strength(-90), 0)
    assert.strictEqual(O.strength(-60), 0.5)
    assert.strictEqual(O.strength(-30), 1)
    assert.strictEqual(O.strength(-120), 0)
    assert.strictEqual(O.strength(null), 0)
    assert.strictEqual(O.strength("loud"), 0)
    assert.strictEqual(O.angleFor("aa:bb"), O.angleFor("aa:bb"))
    assert.strictEqual(O.angleFor(""), 0)
    assert.strictEqual(O.angleFor(null), 0)
    assert.strictEqual(O.signalText({ rssi: -42 }), "-42 dBm")
    assert.strictEqual(O.signalText({ rssi: null }), "signal unknown")
    assert.strictEqual(O.signalText(null), "signal unknown")
})

test("doctor and the clock", () => {
    const d = O.doctorModel('noise\n{"ready":false,"missing":[{"id":"driver","say":"Install it."}],' +
        '"offers":[{"id":"core","say":"Maybe."},{"id":1}]}')
    assert.deepStrictEqual(d, {
        ready: false,
        missing: [{ id: "driver", say: "Install it." }],
        offers: [{ id: "core", say: "Maybe." }]
    })
    assert.strictEqual(O.doctorText(d), "Install it.")
    assert.strictEqual(O.doctorText(O.doctorModel("[]")), "")
    assert.deepStrictEqual(O.doctorModel("nothing"), { ready: true, missing: [], offers: [] })
    assert.deepStrictEqual(O.doctorModel("{bad"), { ready: true, missing: [], offers: [] })
    assert.deepStrictEqual(O.doctorModel('{"ready":true}'), { ready: true, missing: [], offers: [] })

    assert.strictEqual(O.checkedText(0, 1000), "not checked yet")
    assert.strictEqual(O.checkedText(1000, 1000), "checked just now")
    assert.strictEqual(O.checkedText(1000, 9000), "checked 8 s ago")
    assert.strictEqual(O.checkedText(0, 120000), "not checked yet")
    assert.strictEqual(O.checkedText(1000, 121000), "checked 2 min ago")
    assert.strictEqual(O.checkedText(1000, 3601000), "checked 1 h ago")

    assert.strictEqual(O.pollMs(["bar"], 5, "on"), 15000)
    assert.strictEqual(O.pollMs(["popup"], 5, "on"), 5000)
    assert.strictEqual(O.pollMs(["widget"], 3, "starting"), 3000)
    assert.strictEqual(O.pollMs(["popup"], 3, "waiting"), 3000)
    assert.strictEqual(O.pollMs(["popup"], 0, "on"), 5000)
    assert.strictEqual(O.pollMs(["popup"], 500, "on"), 60000)
    assert.strictEqual(O.pollMs(undefined, "x", "on"), 15000)
    assert.strictEqual(O.pollMs(["popup"], 2.9, "on"), 2000)
})

test("emptyModel is the shape every surface can read", () => {
    assert.deepStrictEqual(O.emptyModel("missing", "x"), {
        state: "missing", message: "x", receiving: false, visible: null, remaining: null,
        name: "", dir: "", mode: "off", reason: "", rxProven: false, sound: true,
        visibility: "everyone", senders: 0
    })
    assert.strictEqual(O.emptyModel().state, "error")
})
