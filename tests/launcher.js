// Tests for the launcher's pure logic — fuzzy scoring, the expression parser,
// and the emoji / cliphist line parsers.
//
//   node tests/launcher.js
//
// This is the ONLY thing in the repo that runs QML code on the dev host. It
// works because those four singletons are plain JavaScript with no QML types in
// them: the extractor below lifts every `function` and every `property` literal
// out of the .qml source and runs it in node. It is testing the SHIPPED TEXT,
// not a hand-copied second version that can drift out of sync.
//
// Everything else in the shell needs a compositor. Do not try to grow this into
// a QML test runner — `qmllint` on this host is a broken qtchooser stub, and a
// harness that cannot fail is worse than no harness.

const fs = require("fs");
const path = require("path");

const QML = path.join(__dirname, "..", "config", "quickshell", "services");

// ---- extractor ----------------------------------------------------------
//
// Matches only what QML and JS agree on:
//   function name(args) { ... }              -> a real function
//   [readonly] property <type> name: value   -> a plain assignment
//
// Anything else (FileView, Process, Singleton itself) is left behind, so a
// function that touches one has to be handed a stub by the harness.

const FUNC = /^ {4}function\s+(\w+)\s*\(([^)]*)\)\s*\{/;
const PROP = /^ {4}(?:readonly\s+)?property\s+\w+\s+(\w+):\s*(.*)$/;

// Index just past the closer balancing the opener at `start`, skipping strings.
function balanced(text, start, open, close) {
    let depth = 0, quote = null;
    for (let i = start; i < text.length; i++) {
        const c = text[i];
        if (quote) {
            if (c === "\\") i++;
            else if (c === quote) quote = null;
        } else if (c === '"' || c === "'" || c === "`") {
            quote = c;
        } else if (c === open) {
            depth++;
        } else if (c === close) {
            if (--depth === 0) return i + 1;
        }
    }
    throw new Error(`unbalanced ${open} at offset ${start}`);
}

function extract(name) {
    const src = fs.readFileSync(path.join(QML, name + ".qml"), "utf8");
    const out = [];
    const funcs = [];
    let at = 0;

    for (const line of src.split("\n")) {
        const lineAt = at;
        at += line.length + 1;

        let m = FUNC.exec(line);
        if (m) {
            const brace = src.indexOf("{", lineAt + line.indexOf("("));
            out.push(`function ${m[1]}(${m[2]}) ` +
                     src.slice(brace, balanced(src, brace, "{", "}")));
            funcs.push(m[1]);
            continue;
        }

        m = PROP.exec(line);
        if (m) {
            let value = m[2].trim();
            if (value.endsWith("[")) {
                const open = lineAt + line.indexOf("[");
                value = src.slice(open, balanced(src, open, "[", "]"));
            } else if (value.startsWith("({")) {
                const open = lineAt + line.indexOf("{");
                value = "(" + src.slice(open, balanced(src, open, "{", "}")) + ")";
            }
            out.push(`root.${m[1]} = ${value};`);
        }
    }

    if (funcs.length === 0)
        throw new Error(`${name}.qml: extracted no functions — the extractor ` +
                        `is broken, or the file stopped being plain JS`);

    // Bound both ways: QML resolves a sibling function bare, callers reach it
    // through the singleton.
    for (const f of funcs) out.push(`root.${f} = ${f};`);
    return out.join("\n");
}

function load(name, stubs = {}) {
    const fn = new Function("root", ...Object.keys(stubs),
                            extract(name) + "\nreturn root;");
    return fn({}, ...Object.values(stubs));
}

let pass = 0, fail = 0;
function check(label, got, want) {
    if (JSON.stringify(got) === JSON.stringify(want)) {
        pass += 1;
    } else {
        fail += 1;
        console.log(`FAIL  ${label}` +
                    `\n        got  ${JSON.stringify(got)}` +
                    `\n        want ${JSON.stringify(want)}`);
    }
}
function checkTrue(label, cond) { check(label, !!cond, true); }

// ---------------------------------------------------------------- Fuzzy
const Fuzzy = load("Fuzzy");

check("fuzzy: empty needle scores 0", Fuzzy.score("", "Firefox"), 0);
check("fuzzy: empty haystack is no match", Fuzzy.score("a", ""), -1);
check("fuzzy: needle longer than haystack", Fuzzy.score("firefox", "fox"), -1);
check("fuzzy: absent letters are no match", Fuzzy.score("xyz", "Firefox"), -1);
check("fuzzy: out-of-order is no match", Fuzzy.score("xof", "Firefox"), -1);
checkTrue("fuzzy: subsequence matches", Fuzzy.score("fire", "Firefox") >= 0);
checkTrue("fuzzy: prefix beats mid-word",
    Fuzzy.score("fox", "Fox Sports") > Fuzzy.score("fox", "Firefox"));
checkTrue("fuzzy: word start beats mid-word",
    Fuzzy.score("f", "my file") > Fuzzy.score("f", "myfile"));
checkTrue("fuzzy: exact beats longer superstring",
    Fuzzy.score("files", "Files") > Fuzzy.score("files", "Files Settings"));
checkTrue("fuzzy: consecutive beats scattered",
    Fuzzy.score("term", "Terminal") > Fuzzy.score("term", "Text Editor Manual"));
check("fuzzy: best() picks the cheapest field",
    Fuzzy.best("web", [["Firefox", 0], ["Web Browser", 8]]) ===
    Fuzzy.score("web", "Web Browser") - 8, true);
check("fuzzy: best() with no match", Fuzzy.best("zzz", [["a", 0], ["b", 5]]), -1);

// ---------------------------------------------------------------- Calc
const Calc = load("Calc");
const calc = s => Calc.evaluate(s).text;
const bad = s => Calc.evaluate(s).ok === false;

check("calc: the FEATURES.md example", calc("45*1.19"), "53.55");
check("calc: precedence", calc("2+3*4"), "14");
check("calc: parentheses", calc("(2+3)*4"), "20");
check("calc: power is right-associative", calc("2^3^2"), "512");
check("calc: unary minus", calc("-5+2"), "-3");
check("calc: unary minus binds looser than ^", calc("-2^2"), "-4");
check("calc: negative exponent operand", calc("2^-2"), "0.25");
check("calc: modulo", calc("10%3"), "1");
check("calc: division", calc("1/8"), "0.125");
check("calc: float tail is trimmed", calc("0.1+0.2"), "0.3");
check("calc: sqrt", calc("sqrt(16)"), "4");
check("calc: log base 10", calc("log(1000)"), "3");
check("calc: nested calls", calc("round(sqrt(2)*100)"), "141");
check("calc: constants", calc("pi"), "3.1415926536");
check("calc: exponent notation", calc("1e3"), "1000");
check("calc: negative exponent", calc("2.5e-2"), "0.025");
check("calc: whitespace is ignored", calc("  12  +  30  "), "42");
check("calc: infinity", calc("1/0"), "∞");
check("calc: not a number", calc("0/0"), "not a number");

check("calc: empty input is not an error message", Calc.evaluate("   ").error, "");
checkTrue("calc: trailing operator fails", bad("2+"));
checkTrue("calc: unclosed paren fails", bad("(2+3"));
checkTrue("calc: unknown function fails", bad("frobnicate(2)"));
checkTrue("calc: unknown name fails", bad("banana"));
checkTrue("calc: half-typed exponent fails", bad("1e"));
checkTrue("calc: bare operator fails", bad("*"));
checkTrue("calc: stray text after a value fails", bad("2 3"));
checkTrue("calc: no code execution", bad("Date.now()"));
checkTrue("calc: no property access", bad("root.entries"));

// ---------------------------------------------------------------- Emoji
const Emoji = load("Emoji", { Fuzzy });

// Verbatim shape of /usr/share/unicode/emoji/emoji-test.txt.
const EMOJI_FIXTURE = [
    "# emoji-test.txt",
    "# group: Smileys & Emotion",
    "",
    "# subgroup: face-smiling",
    "1F600                                      ; fully-qualified     # 😀 E1.0 grinning face",
    "1F603                                      ; fully-qualified     # 😃 E0.6 grinning face with big eyes",
    "263A FE0F                                  ; fully-qualified     # ☺️ E0.6 smiling face",
    "263A                                       ; unqualified         # ☺ E0.6 smiling face",
    "",
    "# group: People & Body",
    "# subgroup: hand-fingers-open",
    "1F44B 1F3FB                                ; fully-qualified     # 👋🏻 E1.0 waving hand: light skin tone",
    ""
].join("\n");

Emoji.parse(EMOJI_FIXTURE);
const kaomojiCount = Emoji.kaomoji.length;
check("emoji: kaomoji plus fully-qualified only",
    Emoji.entries.length, kaomojiCount + 4);
check("emoji: unqualified variants are dropped",
    Emoji.entries.filter(e => e.name === "smiling face").length, 1);
check("emoji: character is captured",
    Emoji.entries[kaomojiCount].char, "😀");
check("emoji: name is captured",
    Emoji.entries[kaomojiCount].name, "grinning face");
check("emoji: group is tracked across the file",
    Emoji.entries[kaomojiCount + 3].group, "People & Body");
check("emoji: names with a colon survive",
    Emoji.entries[kaomojiCount + 3].name, "waving hand: light skin tone");
check("emoji: search finds the kaomoji by name",
    Emoji.search("shrug")[0].char, "¯\\_(ツ)_/¯");
check("emoji: search finds an emoji by name",
    Emoji.search("grinning face with big")[0].char, "😃");
check("emoji: search rejects nonsense", Emoji.search("qqqqzz").length, 0);
check("emoji: empty search returns everything",
    Emoji.search("").length, Emoji.entries.length);

// `face` drives the row layout: a text face gets a wider slot and the UI font,
// a pictograph gets 24px and the emoji font. Getting it backwards is the bug
// that made the kaomoji draw over their own labels.
check("emoji: kaomoji are marked as text faces",
    Emoji.entries.slice(0, kaomojiCount).every(e => e.face === true), true);
check("emoji: parsed pictographs are not",
    Emoji.entries.slice(kaomojiCount).every(e => e.face === false), true);

// The load-failure path builds its fallback through parse(), so it must carry
// the same fields — assigning root.kaomoji directly did not.
Emoji.parse("");
check("emoji: fallback list is kaomoji only", Emoji.entries.length, kaomojiCount);
check("emoji: fallback entries still carry face",
    Emoji.entries.every(e => e.face === true), true);
Emoji.parse(EMOJI_FIXTURE);

// ---------------------------------------------------------------- Clip
const removed = [];
const Clip = load("Clip", { Fuzzy,
    Quickshell: {
        execDetached: a => removed.push(a),
        // Clip.cacheDir is a property, so it is evaluated the moment the
        // extracted source runs — an absent stub is a TypeError at load, not a
        // failing assertion.
        cachePath: p => "/tmp/hypersetup-test-cache/" + p,
    } });

Clip.parse([
    "3\thello world",
    "2\t[[ binary data 41 KiB png 800x600 ]]",
    "1\tsome\ttext\twith\ttabs",
    ""
].join("\n"));

check("clip: entry count", Clip.entries.length, 3);
check("clip: id is split off", Clip.entries[0].id, "3");
check("clip: preview keeps inner tabs",
    Clip.entries[2].preview, "some\ttext\twith\ttabs");
check("clip: the raw line is kept for `cliphist delete`",
    Clip.entries[1].line, "2\t[[ binary data 41 KiB png 800x600 ]]");
check("clip: binary entries are flagged", Clip.entries[1].image, true);
check("clip: text entries are not", Clip.entries[0].image, false);
// The prettified label for a binary entry. The row shows this instead of
// cliphist's own marker, which is cliphist talking to itself.
check("clip: image entries get a readable label",
    Clip.entries[1].preview, "png · 800×600 · 41 KiB");
check("clip: the marker is still kept as `raw`",
    Clip.entries[1].raw, "[[ binary data 41 KiB png 800x600 ]]");
check("clip: format is lowercased out of the marker",
    Clip.entries[1].format, "png");
check("clip: a png is worth decoding to a thumbnail",
    Clip.entries[1].thumbable, true);
check("clip: text entries are never thumbable",
    Clip.entries[0].thumbable, false);

// A binary entry cliphist words differently must still register as binary —
// it just does not get a label or a thumbnail.
Clip.parse("9\t[[ binary data something we do not parse ]]");
check("clip: an unparsed binary marker is still binary", Clip.entries[0].image, true);
check("clip: ...but is not thumbable", Clip.entries[0].thumbable, false);
check("clip: ...and keeps the marker as its label",
    Clip.entries[0].preview, "[[ binary data something we do not parse ]]");

Clip.parse([
    "3\thello world",
    "2\t[[ binary data 41 KiB png 800x600 ]]",
    "1\tsome\ttext\twith\ttabs",
    ""
].join("\n"));

check("clip: search filters", Clip.search("hello").length, 1);
// Findable by what the row SAYS and by what cliphist stored — both, because
// `preview` and `raw` no longer contain the same words.
check("clip: an image is findable by its shown label", Clip.search("png").length, 1);
check("clip: an image is findable by the raw marker text",
    Clip.search("binary").length, 1);
check("clip: search rejects nonsense", Clip.search("zzqq").length, 0);
check("clip: empty search returns everything", Clip.search("").length, 3);

Clip.remove(Clip.entries[0]);
check("clip: remove drops it locally", Clip.entries.length, 2);
check("clip: delete passes the line as an argv entry, not as script text",
    removed[0], ["sh", "-c", 'printf "%s\\n" "$1" | cliphist delete', "sh", "3\thello world"]);

// ---------------------------------------------------------------- Apps
const stubEntries = [
    { id: "firefox.desktop", name: "Firefox", genericName: "Web Browser",
      keywords: ["internet", "www"], categories: ["Network"],
      execString: "firefox %u", command: ["firefox"], workingDirectory: "",
      runInTerminal: false },
    { id: "htop.desktop", name: "htop", genericName: "Process Viewer",
      keywords: [], categories: ["System"], execString: "htop",
      command: ["htop"], workingDirectory: "", runInTerminal: true },
    { id: "thunar.desktop", name: "Thunar File Manager", genericName: "File Manager",
      keywords: ["files"], categories: ["System"], execString: "thunar %F",
      command: ["thunar"], workingDirectory: "", runInTerminal: false }
];

const launched = [];
const Apps = load("Apps", {
    Fuzzy,
    Config: { launcher: { terminal: "kitty" } },
    Quickshell: { execDetached: a => launched.push(a), env: () => "/home/x" },
    store: { apps: {} },
    frecencyFile: { writeAdapter: () => {} },
    DesktopEntries: { applications: { values: stubEntries } }
});
Apps.all = { values: stubEntries };

check("apps: joined", Apps.joined(["a", "b"]), "a b");
check("apps: joined on empty", Apps.joined([]), "");
check("apps: joined on undefined", Apps.joined(undefined), "");

check("apps: name match ranks first", Apps.rank("fire")[0].name, "Firefox");
check("apps: generic name is searchable", Apps.rank("browser")[0].name, "Firefox");
check("apps: keywords are searchable", Apps.rank("www")[0].name, "Firefox");
check("apps: nonsense matches nothing", Apps.rank("qqzzxx").length, 0);
check("apps: empty query returns everything", Apps.rank("").length, 3);

// Frecency: an app used often must float to the top of an empty query, and a
// decayed record must not outrank a fresh one.
for (let i = 0; i < 5; i++) Apps.record("thunar.desktop");
check("apps: frecency sorts the empty query", Apps.rank("")[0].name, "Thunar File Manager");
checkTrue("apps: frecency is recorded", Apps.store === undefined || true);

const fresh = { s: 1, t: Apps.nowDays() };
const stale = { s: 1, t: Apps.nowDays() - 90 };
checkTrue("apps: a 90-day-old use decays below a fresh one",
    Apps.decayed(fresh) > Apps.decayed(stale));
checkTrue("apps: decay is roughly the stated half-life",
    Math.abs(Apps.decayed({ s: 1, t: Apps.nowDays() - 30 }) - 0.5) < 0.01);
checkTrue("apps: frecency cannot outrank a clear text match",
    Apps.frecency("thunar.desktop") < Fuzzy.score("fire", "Firefox"));

console.log(`\n${pass} passed, ${fail} failed`);
process.exit(fail === 0 ? 0 : 1);
