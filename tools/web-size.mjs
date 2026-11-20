// tools/web-size.mjs: a web build's code as a player downloads it, and the ratchet that holds it to its record (GFX-1's
// part 6, step 4; kyoten's docs/design/rendering.md § Decided, 2026-11-20). node 22 or later; no npm packages.
//
//   node tools/web-size.mjs measure <wasm> <js>                              # "<wasm> <js>": each file's bytes after brotli
//   node tools/web-size.mjs check <record.json> <wasm> <js> <emcc>           # held to the record's entry for that emcc
//   node tools/web-size.mjs record <record.json> <wasm> <js> <kama> <emcc> <why>   # appended as that emcc's record
//
// What is measured is a build's wasm plus its JS, each compressed by brotli at quality 11, the best a server can store
// ahead of time, without the page shell or assets (kyoten's research/web-baseline.md § Method); node's brotli gives the
// `brotli -q 11` command line's bytes. A build's bytes are its toolchain's as much as its source's (emscripten writes
// the JS, and Closure breaks its lines with the host's line ending), so each entry names the emcc that built it, and a
// build is held to the last entry for its own emcc, as a frame is held to its own software GPU's golden.
//
// `check` fails when the build is above its record, saying by how much: raising a record takes a written reason, as
// every budget does, and never refuses a feature (FEATURES.md § How to read a row). A build below its record passes and
// says to lower it, so the record keeps identifying growth. `record` appends an entry, its date, the kama and the emcc
// it was built with, the bytes and the reason, so the record's history is every size the build has had and why;
// tools/update-web-size.sh calls it.
import fs from 'node:fs';
import zlib from 'node:zlib';

const RECORD_HOW = 'tools/update-web-size.sh "<why>"';

function brotli(file) {
    return zlib.brotliCompressSync(fs.readFileSync(file), {
        params: { [zlib.constants.BROTLI_PARAM_QUALITY]: 11 },
    }).length;
}

// The two byte counts a command was handed, or why they are not.
function counts(wasm, js) {
    const whole = s => /^[0-9]+$/.test(s);
    if (!whole(wasm) || !whole(js)) return { why: `FAIL the measurement is not two byte counts: '${wasm}' and '${js}'` };
    const w = Number(wasm), j = Number(js);
    if (w === 0 || j === 0) return { why: `FAIL a part of the build measured nothing: wasm ${w} B, JS ${j} B` };
    return { w, j };
}

// The record at `file` and its last entry for `emcc`, or why they cannot be used. With `starting`, `record` may begin
// a record, or the first entry for an emcc.
function readRecord(file, emcc, starting) {
    if (!fs.existsSync(file)) {
        return starting ? { record: null, last: null } : { why: `FAIL no record at ${file}: write one with ${RECORD_HOW}` };
    }
    let record;
    try { record = JSON.parse(fs.readFileSync(file, 'utf8')); } catch { return { why: `FAIL the record at ${file} is not JSON` }; }
    if (!record || !Array.isArray(record.history)) return { why: `FAIL the record at ${file} has no history` };
    const mine = record.history.filter(e => e && e.emcc === emcc);
    if (mine.length === 0) {
        if (starting) return { record, last: null };
        const others = [...new Set(record.history.map(e => e && e.emcc))].join(', ') || 'none';
        return { why: `FAIL the record at ${file} has no entry for emcc ${emcc} (it has ${others}): write one with ${RECORD_HOW}` };
    }
    const last = mine[mine.length - 1];
    const of = `the record's last entry for emcc ${emcc}, of ${last.date},`;
    const whole = n => Number.isInteger(n) && n > 0;
    if (!whole(last.wasm) || !whole(last.js) || !whole(last.code)) {
        return { why: `FAIL ${of} does not give its wasm, JS and code as byte counts` };
    }
    if (typeof last.why !== 'string' || last.why.trim() === '') return { why: `FAIL ${of} gives no reason` };
    if (last.code !== last.wasm + last.js) {
        return { why: `FAIL ${of} says ${last.code} B of code, where its wasm and JS are ${last.wasm + last.js} B` };
    }
    return { record, last };
}

function check(file, wasm, js, emcc) {
    const m = counts(wasm, js);
    if (m.why) return [m.why, 1];
    const r = readRecord(file, emcc, false);
    if (r.why) return [r.why, 1];
    const code = m.w + m.j, limit = r.last.code;
    const said = `${code} B of web code (wasm ${m.w} B, JS ${m.j} B) on emcc ${emcc}`;
    if (code > limit) return [`FAIL ${said}, ${code - limit} B over its record's ${limit} B: raising the record takes a written reason (${RECORD_HOW})`, 1];
    if (code < limit) return [`ok   ${said}, ${limit - code} B under its record's ${limit} B: lower the record (${RECORD_HOW})`, 0];
    return [`ok   ${said}, as its record says`, 0];
}

function record(file, wasm, js, kama, emcc, why) {
    if (typeof why !== 'string' || why.trim() === '') return ['FAIL a record takes a written reason', 1];
    if (!/^[0-9]+(\.[0-9]+)+$/.test(emcc)) return [`FAIL '${emcc}' is not an emcc version`, 1];
    const m = counts(wasm, js);
    if (m.why) return [m.why, 1];
    // A record that cannot be read is never overwritten, nor one whose entry for this emcc is broken: a person looks
    // at it first.
    const r = readRecord(file, emcc, true);
    if (r.why) return [r.why, 1];
    const code = m.w + m.j;
    const rec = r.record || {
        measures: 'examples/cube as a player gets it: built for the web at --release with --define CUBE_PLAYER, which ' +
            'leaves its harness out; its wasm plus its JS, each at brotli quality 11, without the page shell or assets ' +
            '(tools/web-size.mjs). Each entry is a size the build had on the emcc it names, and why.',
        history: [],
    };
    if (r.last && r.last.code === code && r.last.wasm === m.w && r.last.js === m.j) {
        return [`FAIL the record already says ${code} B (wasm ${m.w} B, JS ${m.j} B) for emcc ${emcc}`, 1];
    }
    const now = new Date();
    const date = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-${String(now.getDate()).padStart(2, '0')}`;
    rec.history.push({ date, kama, emcc, wasm: m.w, js: m.j, code, why: why.trim() });
    fs.writeFileSync(file, JSON.stringify(rec, null, 2) + '\n');
    const before = r.last ? `, where it said ${r.last.code} B` : '';
    return [`recorded ${code} B of web code (wasm ${m.w} B, JS ${m.j} B) on emcc ${emcc} in ${file}${before}`, 0];
}

const [cmd, ...args] = process.argv.slice(2);
let out;
if (cmd === 'measure' && args.length === 2) {
    try { out = [`${brotli(args[0])} ${brotli(args[1])}`, 0]; } catch (e) { out = [`FAIL cannot measure: ${e.message}`, 1]; }
} else if (cmd === 'check' && args.length === 4) {
    out = check(...args);
} else if (cmd === 'record' && args.length === 6) {
    out = record(...args);
} else {
    out = ['usage: node tools/web-size.mjs measure <wasm> <js> | check <record> <wasm> <js> <emcc> | ' +
        'record <record> <wasm> <js> <kama> <emcc> <why>', 2];
}
console.log(out[0]);
process.exit(out[1]);
