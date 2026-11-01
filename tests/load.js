// Loads a plugin `.pragma library` file into node, so the tests run the code the shell does.
const fs = require("fs")
const path = require("path")
const vm = require("vm")

module.exports = function load(rel, names) {
    const file = path.join(__dirname, "..", rel)
    // The pragma line is blanked, not removed, so line numbers stay the file's own.
    const src = fs.readFileSync(file, "utf8").replace(".pragma library", "")
    const wrapped = "(function () {" + src + "\n;return {" + names.map(n => n + ":" + n).join(",") + "}})"
    return vm.runInThisContext(wrapped, { filename: file })()
}
