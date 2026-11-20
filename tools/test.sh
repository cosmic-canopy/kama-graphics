#!/usr/bin/env bash
# tools/test.sh — @kama/graphics' gate: the roadmap and the feature map held to their rules, the library, its tests and
# examples/cube checked, and the tests program and the cube run natively, debug and release, and built for the web, debug
# and release, and run in every headless browser present, every frame held to its software GPU's golden where the leg
# names one (tools/legs.sh). The cube's is its window's last frame, read back from the window.
#
#   tools/test.sh
#
# Run it from msys2 UCRT64 on Windows (bash -lic, so emcc and node are on PATH for the web leg), or any shell elsewhere.
# The web leg is built when `emcc` is on PATH and run, headless, under `kama run --target WASM` in every browser
# tools/browsers.mjs finds: Edge and Chrome as installed, the pinned Firefox and the pinned Chrome for Testing
# (KAMA_BROWSER names one). Each part is skipped, and says so, without what it needs.
#
# The goldens (tests/goldens/<test>/<gpu>.png, and the cube's examples/cube/goldens/<gpu>.png) are never written here. A
# frame that differs from its golden, or has none,
# fails its leg and is printed as a `golden-png` line; tools/update-goldens.sh, run on purpose, writes those, and the
# change is reviewed in its diff.
set -euo pipefail
. "$(dirname "$0")/legs.sh"

# The gate's last word on itself: a run that printed a FAIL line fails, whatever its status, so a check that prints FAIL
# and forgets to set `failed` cannot pass (found by GFX-1's part 6, step 4's mutations, where the ratchet's status was
# dropped). A passing gate prints none. The gate runs itself once more under tee and holds its own output to that.
failLines() { grep -c '^FAIL' "$1" || true; }
if [ -z "${KG_GATE_INNER:-}" ]; then
    KG_GATE_INNER=1 bash "$ROOT/tools/test.sh" "$@" 2>&1 | tee tests/out/gate.log && status=0 || status=$?
    if [ "$status" = 0 ] && [ "$(failLines tests/out/gate.log)" != 0 ]; then
        echo "FAIL the gate printed $(failLines tests/out/gate.log) FAIL line(s) above, though its own status said it passed"
        echo "test: FAILED" >&2
        exit 1
    fi
    exit "$status"
fi

failed=0
step() { echo; echo "== $*"; }
rm -f tests/out/run-*.log   # this run's logs only, for the goldens' last word below

# A leg that names a software GPU compares every golden tests/goldens/ has for it, and each matches: the run's last word
# on its goldens must count exactly that many declared and matched, so a run that skipped one, or a golden no case
# compares any more, fails. A leg that names none must say it compared none.
goldensHeld() {
    local log="$1" gpu="$2" leg="$3" want printed said
    # Every leg, whether it names a GPU or not, runs its GPU cases to the end: one whose device never opened fails here.
    if grep -qx 'gpu cases: all run' "$log"; then
        echo "ok   every GPU case ran ($leg)"
    else
        echo "FAIL ($leg) its GPU cases did not all run"
        failed=1
    fi
    printed="$(grep -c '^golden-png ' "$log" || true)"
    said="$(grep '^goldens: ' "$log" || echo 'no goldens line')"
    if [ -z "$gpu" ]; then
        if [ "$said" = "goldens: none, this leg names no software GPU" ] && [ "$printed" = 0 ]; then
            echo "ok   this leg names no software GPU, and compared no golden ($leg)"
        else
            echo "FAIL ($leg) names no software GPU: $said, and $printed frame(s) printed"
            failed=1
        fi
        return
    fi
    want="$(find tests/goldens -mindepth 2 -maxdepth 2 -name "$gpu.png" | wc -l | tr -d ' ')"
    if [ "$printed" = 0 ] && [ "$want" -gt 0 ] && [ "$said" = "goldens: $want declared, $want matched, on $gpu" ]; then
        echo "ok   every golden tests/goldens/ has for $gpu, $want, compared and matched ($leg)"
    else
        echo "FAIL ($leg) --golden $gpu: $said; tests/goldens/ has $want for $gpu, and $printed frame(s) were printed"
        failed=1
    fi
}

# A misuse the library refuses is printed by default (kyoten's rendering.md § Decided, GFX-1's part 2, question 4), which
# only the run's output can show: the tests' renderer that prints refuses one render, the one told not to print refuses
# 70 and must print none, the tree refuses five adds (tests/src/boxes.kama and parts.kama), a renderer refuses one
# material, rendered twice (tests/src/shaders.kama), one directional light at its own target, drawn twice
# (tests/src/lights.kama), and one material's pipeline the device refuses, found by a render of the renderer that prints
# and never reads takeErrors() (tests/src/compiling.kama). Each refusal printed once, on every leg. A mesh's two
# pipelines, shaded and depth-only, are refused as one, in the words of whichever is found first, since natively each
# answers on its own: either counts, once.
refusalsPrinted() {
    local log="$1" leg="$2" renders adds materials lights pipelines
    renders="$(grep -c '@kama/graphics: render drew nothing' "$log" || true)"
    adds="$(grep -c '@kama/graphics: add refused' "$log" || true)"
    materials="$(grep -c '@kama/graphics: a material was refused' "$log" || true)"
    lights="$(grep -c '@kama/graphics: a directional light sits at its own target' "$log" || true)"
    pipelines="$(grep -cE "@kama/graphics: a material's (depth-only )?pipeline was refused by the device" "$log" || true)"
    if [ "$renders" = 1 ] && [ "$adds" = 5 ] && [ "$materials" = 1 ] && [ "$lights" = 1 ] && [ "$pipelines" = 1 ]; then
        echo "ok   each refused misuse was printed once, and none by the renderer told not to print ($leg)"
    else
        echo "FAIL ($leg) the refused misuses printed: ${renders} render line(s), not 1, ${adds} add line(s), not 5, ${materials} material line(s), not 1, ${lights} light line(s), not 1, and ${pipelines} pipeline line(s), not 1"
        failed=1
    fi
}

# Every leg runs a debug build and a release build, natively and on the web (kyoten's rendering.md § Decided,
# 2026-11-17): a wasm release runs Closure over the page's JS since kama 0.9.966 (KR-289), which renames every name it
# cannot prove the browser's, and a game ships that build. The JS it runs over is @kama/gpu's and @kama/window's, whose
# gates hold their names; this one holds the library to its goldens in both builds.
#
# A run's first line is what its program was built as (`build: debug` or `build: release`), so a leg that lost its
# `--release` fails here rather than passing as the leg it names.
builtAs() {
    local log="$1" mode="$2" leg="$3"
    if tr -d '\r' < "$log" | grep -qx "build: $mode"; then
        echo "ok   $leg ran a $mode build"
    else
        echo "FAIL $leg: its program never said \"build: $mode\", so the leg ran another build"
        failed=1
    fi
}

# examples/cube's run (GFX-1's part 6, steps 2 and 3; tools/legs.sh): CUBE_FRAMES frames drawn into its window with no
# misuse, and its last frame read back from the window and held. On a leg naming a software GPU that frame is the golden's
# bytes, examples/cube/goldens/<gpu>.png, and no frame is printed; on a player's GPU held against a software GPU's golden
# by FLIP (`--flip-against`), it is within FLIP's two limits, and no frame is printed; on a leg naming neither, the frame
# reads back as drawn.
cubeHeld() {
    local log="$1" gpu="$2" leg="$3" flip="${4:-}" said
    said="$(grep -E '^FAIL|^cube: ' "$log" | grep -v "^cube: $CUBE_FRAMES frames drawn, 0 misuses reported$" | cut -c1-200 | head -3 || true)"
    if ! grep -qx "cube: $CUBE_FRAMES frames drawn, 0 misuses reported" "$log"; then
        echo "FAIL examples/cube ($leg) did not draw $CUBE_FRAMES frames with no misuse reported: ${said:-it said nothing}"
        failed=1
    elif [ -n "$gpu" ]; then
        if grep -q "^ok   golden cube on $gpu: " "$log" && ! grep -q '^golden-png ' "$log"; then
            echo "ok   examples/cube's last frame, read back from its window, is its $gpu golden ($leg)"
        else
            echo "FAIL examples/cube ($leg) --golden $gpu: its last frame is not its golden: ${said:-it said nothing}"
            failed=1
        fi
    elif [ -n "$flip" ]; then
        if grep -q "^ok   flip cube against $flip: " "$log" && ! grep -q '^frame-png ' "$log"; then
            echo "ok   examples/cube's last frame, read back from its window, is within FLIP's limits of its $flip golden ($leg)"
            grep "^info flip cube against $flip: mean " "$log" | cut -c1-160 || true
        else
            echo "FAIL examples/cube ($leg) --flip-against $flip: its last frame is not within FLIP's limits: ${said:-it said nothing}"
            failed=1
        fi
    elif grep -qx "cube: the window's last frame reads back as drawn" "$log"; then
        echo "ok   examples/cube's last frame, read back from its window, is as drawn ($leg)"
    else
        echo "FAIL examples/cube ($leg) did not read its last frame back as drawn: ${said:-it said nothing}"
        failed=1
    fi
}

step "the roadmap"
tools/check-roadmap.sh || failed=1

step "the feature map"
tools/check-features.sh || failed=1

step "update-goldens refuses when the legs of one software GPU disagree (tools/goldens-agree.sh, on crafted records)"
# One case: its name, what goldens-agree.sh must say and its status, then the records (ran, verdicts, lines; \n between).
agreeCase() {
    local name="$1" want="$2" dir="tests/out/agree/$1" got
    mkdir -p "$dir"
    printf '%b' "$3" > "$dir/ran"
    printf '%b' "$4" > "$dir/verdicts"
    printf '%b' "$5" > "$dir/lines"
    got="$(tools/goldens-agree.sh "$dir"; echo "exit $?")"
    if [ "$got" = "$want" ]; then
        echo "ok   update-goldens: $name"
    else
        echo "FAIL update-goldens: $name: said '$got', where '$want'"
        failed=1
    fi
}
ran='native warp\nfirefox warp\nchrome swiftshader\n'
agreeCase "two legs of WARP printing the same frame agree, and it is written" 'exit 0' "$ran" \
    'native FAIL harness warp\nfirefox FAIL harness warp\nchrome ok harness swiftshader\n' \
    'native harness warp AAAA\nfirefox harness warp AAAA\n'
agreeCase "two legs of WARP printing different frames are refused" \
    $'harness warp: native and firefox printed different frames\nexit 1' "$ran" \
    'native FAIL harness warp\nfirefox FAIL harness warp\n' \
    'native harness warp AAAA\nfirefox harness warp BBBB\n'
agreeCase "a frame printed on one leg of WARP while another matched the golden is refused" \
    $'harness warp: firefox matched the golden, and native printed a frame\nexit 1' "$ran" \
    'native FAIL harness warp\nfirefox ok harness warp\n' \
    'native harness warp AAAA\n'
agreeCase "a frame printed on one leg of WARP while another never reached the case is refused" \
    $'harness warp: firefox ran on warp and printed no frame for it\nexit 1' "$ran" \
    'native FAIL harness warp\n' \
    'native harness warp AAAA\n'
agreeCase "a line naming no golden's file is refused" \
    $'a line names "../x warp", not a golden\nexit 1' "$ran" '' 'native ../x warp AAAA\n'

step "the web-size ratchet holds a measurement to its record (tools/web-size.mjs, on crafted records)"
# examples/cube's web code as a player gets it is held to its record, examples/cube/web-size.json (GFX-1's part 6, step 4;
# kyoten's rendering.md § Decided, 2026-11-20). A build's bytes are its toolchain's as much as its source's, so each entry
# names the emcc that built it, and a build is held to the last entry for its own emcc, as a frame is held to its own
# software GPU's golden: a build above it fails, and one below it passes and says to lower it. One case: its name, what
# `check` must say and its status, the record ('-' for none), and the measurement, wasm and JS, in bytes of brotli, on
# emcc 6.0.13.
sizeCase() {
    local name="$1" want="$2" dir="tests/out/web-size/$((++sizeCases))" got
    rm -rf "$dir" && mkdir -p "$dir"
    [ "$3" = - ] || printf '%s' "$3" > "$dir/record.json"
    got="$(node tools/web-size.mjs check "$dir/record.json" "$4" "$5" 6.0.13 2>&1; echo "exit $?")"
    got="${got//$dir\//<dir>/}"
    if [ "$got" = "$want" ]; then
        echo "ok   web-size: $name"
    else
        echo "FAIL web-size: $name: said '$got', where '$want'"
        failed=1
    fi
}
if ! command -v node >/dev/null 2>&1; then
    echo "skip no node on PATH"
else
    sizeCases=0
    # An entry: wasm, JS, code, why, and its emcc (6.0.13 unless named).
    entry() {
        printf '{"date":"2026-11-20","kama":"0.9.978","emcc":"%s","wasm":%s,"js":%s,"code":%s,"why":"%s"}' \
            "${5:-6.0.13}" "$1" "$2" "$3" "$4"
    }
    one="{\"measures\":\"a build\",\"history\":[$(entry 100 50 150 'the first measurement')]}"
    lower='lower the record (tools/update-web-size.sh "<why>")'
    raise='raising the record takes a written reason (tools/update-web-size.sh "<why>")'
    sizeCase "a build its record's size passes" \
        $'ok   150 B of web code (wasm 100 B, JS 50 B) on emcc 6.0.13, as its record says\nexit 0' "$one" 100 50
    sizeCase "a build a byte over its record fails, saying by how much" \
        "FAIL 151 B of web code (wasm 101 B, JS 50 B) on emcc 6.0.13, 1 B over its record's 150 B: $raise"$'\nexit 1' \
        "$one" 101 50
    sizeCase "a build under its record passes, saying to lower the record" \
        "ok   140 B of web code (wasm 100 B, JS 40 B) on emcc 6.0.13, 10 B under its record's 150 B: $lower"$'\nexit 0' \
        "$one" 100 40
    sizeCase "the record is its last entry, not its largest" \
        "FAIL 160 B of web code (wasm 100 B, JS 60 B) on emcc 6.0.13, 10 B over its record's 150 B: $raise"$'\nexit 1' \
        "{\"measures\":\"a build\",\"history\":[$(entry 150 50 200 'before'),$(entry 100 50 150 'smaller')]}" 100 60
    sizeCase "the record is the last entry for the build's own emcc, not another's" \
        $'ok   150 B of web code (wasm 100 B, JS 50 B) on emcc 6.0.13, as its record says\nexit 0' \
        "{\"measures\":\"a build\",\"history\":[$(entry 100 50 150 'here'),$(entry 90 40 130 'another machine' 7.0.0)]}" 100 50
    sizeCase "a record with no entry for the build's emcc fails" \
        $'FAIL the record at <dir>/record.json has no entry for emcc 6.0.13 (it has 7.0.0): write one with tools/update-web-size.sh "<why>"\nexit 1' \
        "{\"measures\":\"a build\",\"history\":[$(entry 100 50 150 'another machine' 7.0.0)]}" 100 50
    sizeCase "a record with no entry at all fails" \
        $'FAIL the record at <dir>/record.json has no entry for emcc 6.0.13 (it has none): write one with tools/update-web-size.sh "<why>"\nexit 1' \
        '{"measures":"a build","history":[]}' 100 50
    sizeCase "no record fails" \
        $'FAIL no record at <dir>/record.json: write one with tools/update-web-size.sh "<why>"\nexit 1' - 100 50
    sizeCase "a record that is not JSON fails" $'FAIL the record at <dir>/record.json is not JSON\nexit 1' '{"history": [' 100 50
    sizeCase "a record whose entry gives no reason fails" \
        $'FAIL the record\'s last entry for emcc 6.0.13, of 2026-11-20, gives no reason\nexit 1' \
        "{\"measures\":\"a build\",\"history\":[$(entry 100 50 150 '')]}" 100 50
    sizeCase "a record whose code is not its wasm plus its JS fails" \
        $'FAIL the record\'s last entry for emcc 6.0.13, of 2026-11-20, says 151 B of code, where its wasm and JS are 150 B\nexit 1' \
        "{\"measures\":\"a build\",\"history\":[$(entry 100 50 151 'off by one')]}" 100 50
    sizeCase "a measurement with a part of nothing fails" \
        $'FAIL a part of the build measured nothing: wasm 100 B, JS 0 B\nexit 1' "$one" 100 0
    sizeCase "a measurement that is not two byte counts fails" \
        $'FAIL the measurement is not two byte counts: \'abc\' and \'50\'\nexit 1' "$one" abc 50
    # `record` writes the record: with a reason, an entry the check then holds; with none, nothing.
    dir="tests/out/web-size/record"
    rm -rf "$dir" && mkdir -p "$dir"
    said="$(node tools/web-size.mjs record "$dir/record.json" 100 50 0.9.978 6.0.13 '' 2>&1; echo "exit $?")"
    if [ "$said" = $'FAIL a record takes a written reason\nexit 1' ] && [ ! -e "$dir/record.json" ]; then
        echo "ok   web-size: a record with no reason is refused, and nothing is written"
    else
        echo "FAIL web-size: a record with no reason: said '$said', or wrote a record"; failed=1
    fi
    node tools/web-size.mjs record "$dir/record.json" 100 50 0.9.978 6.0.13 'the first measurement' > /dev/null 2>&1 || true
    node tools/web-size.mjs record "$dir/record.json" 90 50 0.9.978 6.0.13 'smaller' > /dev/null 2>&1 || true
    node tools/web-size.mjs record "$dir/record.json" 95 45 0.9.978 7.0.0 'another machine' > /dev/null 2>&1 || true
    said="$(node tools/web-size.mjs check "$dir/record.json" 90 50 6.0.13 2>&1; echo "exit $?")"
    entries="$(node -e 'const r = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8")); console.log(r.history.map(e => e.emcc + ":" + e.code + ":" + e.why).join(","))' "$dir/record.json" 2>&1 || true)"
    if [ "$said" = $'ok   140 B of web code (wasm 90 B, JS 50 B) on emcc 6.0.13, as its record says\nexit 0' ] \
            && [ "$entries" = "6.0.13:150:the first measurement,6.0.13:140:smaller,7.0.0:140:another machine" ]; then
        echo "ok   web-size: a record with a reason is appended as the last entry for its emcc, which the check then holds"
    else
        echo "FAIL web-size: three records, then the check: said '$said', and the entries are '$entries'"; failed=1
    fi
    said="$(node tools/web-size.mjs record "$dir/record.json" 90 50 0.9.978 6.0.13 'again' 2>&1; echo "exit $?")"
    if [ "$said" = $'FAIL the record already says 140 B (wasm 90 B, JS 50 B) for emcc 6.0.13\nexit 1' ]; then
        echo "ok   web-size: a record that changes nothing is refused"
    else
        echo "FAIL web-size: a record that changes nothing: said '$said'"; failed=1
    fi
fi

step "kama check"
"$KAMA" pkg install kama.json > /dev/null
"$KAMA" check kama.json || failed=1
"$KAMA" pkg install tests/kama.json > /dev/null
"$KAMA" check tests/kama.json || failed=1
"$KAMA" pkg install examples/cube/kama.json > /dev/null
"$KAMA" check examples/cube/kama.json || failed=1

gpu="$(nativeGolden)"
for mode in debug release; do
    step "native, $mode${gpu:+, --golden $gpu}"
    if buildNative "$mode"; then
        runNative "$mode" "$gpu" "tests/out/run-$mode.log" || failed=1
        goldensHeld "tests/out/run-$mode.log" "$gpu" "native, $mode"
        refusalsPrinted "tests/out/run-$mode.log" "native, $mode"
        builtAs "tests/out/run-$mode.log" "$mode" "native, $mode"
    else
        failed=1
    fi
done

step "a leg naming a software GPU the harness does not know is refused"
if [ -x "tests/out/native-debug/graphicstests$EXE" ]; then
    if "tests/out/native-debug/graphicstests$EXE" --golden nonesuch < /dev/null > tests/out/unknown-gpu.txt 2>&1; then
        echo "FAIL --golden nonesuch passed"
        failed=1
    elif grep -qx "FAIL --golden names a software GPU the harness knows (warp, swiftshader): it names 'nonesuch'" \
            tests/out/unknown-gpu.txt && grep -qx "goldens: none, this leg names no software GPU" tests/out/unknown-gpu.txt; then
        echo "ok   --golden nonesuch fails the run, and compares no golden"
    else
        tail -5 tests/out/unknown-gpu.txt
        echo "FAIL --golden nonesuch failed, but not as refused"
        failed=1
    fi
else
    echo "FAIL no native debug build to run"
    failed=1
fi

step "a leg naming a software GPU its adapter is not compares no golden and prints no frame"
# Natively on Windows the fallback adapter is WARP, so a run naming SwiftShader must fail on what the adapter says, and
# never hold WARP's frames to SwiftShader's goldens nor print one as SwiftShader's, which update-goldens.sh would write.
if [ "$(nativeGolden)" != warp ]; then
    echo "skip natively this platform's fallback adapter is not WARP"
elif [ -x "tests/out/native-debug/graphicstests$EXE" ]; then
    "tests/out/native-debug/graphicstests$EXE" --golden swiftshader < /dev/null > tests/out/wrong-gpu.txt 2>&1 && code=0 || code=$?
    tr -d '\r' < tests/out/wrong-gpu.txt > tests/out/wrong-gpu.log
    if [ "$code" != 0 ] \
            && grep -q "^FAIL --golden swiftshader: the adapter says SwiftShader exactly where the leg names it: " tests/out/wrong-gpu.log \
            && ! grep -q '^golden-png ' tests/out/wrong-gpu.log && grep -q '^goldens: [0-9]* declared, 0 matched, on swiftshader$' tests/out/wrong-gpu.log; then
        echo "ok   --golden swiftshader on WARP fails the run, compares no golden and prints no frame"
    else
        grep -E '^FAIL|^golden-png|^goldens:' tests/out/wrong-gpu.log | cut -c1-160
        echo "FAIL --golden swiftshader on WARP: the run's status is $code, or it compared or printed a frame"
        failed=1
    fi
else
    echo "FAIL no native debug build to run"
    failed=1
fi

step "examples/cube natively: a lit cube in a window, its last frame read back, on the GPU${gpu:+ and on $gpu}"
# GFX-1's done (ROADMAP_DETAIL § GFX-1): the example draws from one source on both legs, reaches the GPU only through
# the library, releases nothing by hand, and its golden passes on each software GPU's leg.
if ! ls examples/cube/src/*.kama > /dev/null 2>&1; then
    echo "FAIL examples/cube has no source"; failed=1
elif grep -nE '\.raw\(|adopt\(|wgpu[A-Z]|extern fn' examples/cube/src/*.kama; then
    echo "FAIL examples/cube releases or binds by hand (above)"; failed=1
else
    echo "ok   examples/cube releases nothing by hand"
fi
if [ -n "${KAMA_WINDOW_NO_DISPLAY:-}" ]; then
    echo "skip KAMA_WINDOW_NO_DISPLAY is set"
else
    # A machine with a software golden holds its GPU's frame to it by FLIP: a leg that held it to none would pass on the
    # frame being drawn alone.
    if [ -n "$(nativeGolden)" ] && [ -z "$(nativeFlip)" ]; then
        echo "FAIL natively the GPU's frame is held to no golden, though this machine has $(nativeGolden)'s"
        failed=1
    fi
    for mode in debug release; do
        if buildCube "$mode"; then
            flip="$(nativeFlip)"
            echo "-- examples/cube, native, $mode, on the GPU${flip:+, --flip-against $flip}"
            runCube "$mode" "" "tests/out/run-cube-$mode.log" "$flip" || failed=1
            cubeHeld "tests/out/run-cube-$mode.log" "" "native on the GPU, $mode" "$flip"
            builtAs "tests/out/run-cube-$mode.log" "$mode" "examples/cube, native on the GPU, $mode"
            if [ -n "$gpu" ]; then
                echo "-- examples/cube, native, $mode, --golden $gpu"
                runCube "$mode" "$gpu" "tests/out/run-cube-$gpu-$mode.log" || failed=1
                cubeHeld "tests/out/run-cube-$gpu-$mode.log" "$gpu" "native, $mode"
                builtAs "tests/out/run-cube-$gpu-$mode.log" "$mode" "examples/cube, native, $mode, --golden $gpu"
            fi
        else
            failed=1
        fi
    done
    # Natively on Windows the fallback adapter is WARP, so the cube naming SwiftShader must fail on what its renderer
    # says it draws with (renderer.adapterInfo()), and neither hold WARP's frame to SwiftShader's golden nor print it.
    if [ "$(nativeGolden)" = warp ] && [ -x "tests/out/cube-native-debug/cube$EXE" ]; then
        runCube debug swiftshader tests/out/cube-wrong-gpu.log > /dev/null && code=0 || code=$?
        if [ "$code" != 0 ] \
                && grep -q '^FAIL golden cube on swiftshader: the run names swiftshader, and the adapter says kind CPU' tests/out/cube-wrong-gpu.log \
                && ! grep -q '^golden-png ' tests/out/cube-wrong-gpu.log && ! grep -q '^ok   golden cube' tests/out/cube-wrong-gpu.log; then
            echo "ok   examples/cube --golden swiftshader on WARP fails on its adapter, and compares and prints no frame"
        else
            grep -E '^FAIL|^golden-png|^ok   golden|^cube: ' tests/out/cube-wrong-gpu.log | cut -c1-160
            echo "FAIL examples/cube --golden swiftshader on WARP: the run's status is $code, or it compared or printed a frame"
            failed=1
        fi
    fi
    # FLIP's hold itself: the cube on the GPU stopped at half its frames, turned 30 degrees from its golden's, must fail
    # both of FLIP's limits, its mean and its share above the threshold, and print its frame, so a hold that passed every
    # frame, or held to one number alone, would fail here.
    flip="$(nativeFlip)"
    if [ -n "$flip" ] && [ -x "tests/out/cube-native-debug/cube$EXE" ]; then
        "tests/out/cube-native-debug/cube$EXE" --frames $((CUBE_FRAMES / 2)) --flip-against "$flip" < /dev/null 2>&1 | tr -d '\r' \
            > tests/out/cube-flip-other.log && code=0 || code=$?
        if [ "$code" != 0 ] \
                && grep -q "^FAIL flip cube against $flip: its mean error, [0-9.e-]*, is above 0.005; and [0-9]* of its [0-9]* pixels, a share of [0-9.e-]*, err above 0.1, more than " tests/out/cube-flip-other.log \
                && grep -q "^frame-png cube $flip " tests/out/cube-flip-other.log; then
            echo "ok   examples/cube on the GPU turned 30 degrees from its $flip golden fails FLIP's limits, and prints the frame"
            grep "^info flip cube against $flip: mean " tests/out/cube-flip-other.log | cut -c1-160 || true
        else
            grep -E '^FAIL|^ok   flip|^info flip|^cube: ' tests/out/cube-flip-other.log | cut -c1-160
            echo "FAIL examples/cube on the GPU turned from its $flip golden: the run's status is $code, or it did not fail FLIP's limits and print the frame"
            failed=1
        fi
    fi
    # The comparison itself: a run whose last frame is another, the cube a degree short of the golden's, must fail it,
    # saying how its texels differ, and print the frame, so a comparison that passed every frame would fail here.
    if [ -n "$gpu" ] && [ -x "tests/out/cube-native-debug/cube$EXE" ]; then
        "tests/out/cube-native-debug/cube$EXE" --frames $((CUBE_FRAMES - 1)) --golden "$gpu" < /dev/null 2>&1 | tr -d '\r' \
            > tests/out/cube-other-frame.log && code=0 || code=$?
        if [ "$code" != 0 ] && grep -q "^FAIL golden cube on $gpu: [0-9]* of its texels differ from the golden's" tests/out/cube-other-frame.log \
                && grep -q "^golden-png cube $gpu " tests/out/cube-other-frame.log; then
            echo "ok   examples/cube a frame short of its $gpu golden fails it, saying how its texels differ, and prints the frame"
        else
            grep -E '^FAIL|^ok   golden|^cube: ' tests/out/cube-other-frame.log | cut -c1-160
            echo "FAIL examples/cube a frame short of its $gpu golden: the run's status is $code, or it did not fail by its texels and print the frame"
            failed=1
        fi
    fi
fi

step "examples/cube as a player gets it, natively: its harness left out (--define CUBE_PLAYER), it refuses a golden"
# The player's build is the one the web leg measures (below). It says it carries no harness, and a run naming a golden
# fails before it draws, so it can never pass as a golden leg holding nothing.
if buildCubePlayerNative; then
    "tests/out/cube-player-native/cube$EXE" --frames 2 --golden warp < /dev/null 2>&1 | tr -d '\r' \
        > tests/out/cube-player-golden.log && code=0 || code=$?
    if [ "$code" != 0 ] && grep -qx 'harness: out' tests/out/cube-player-golden.log \
            && grep -qx "FAIL this build leaves the harness out (--define CUBE_PLAYER), so it holds no golden: the run names 'warp'" tests/out/cube-player-golden.log \
            && grep -qx 'cube: 0 frames drawn, 0 misuses reported' tests/out/cube-player-golden.log \
            && ! grep -q '^golden-png ' tests/out/cube-player-golden.log; then
        echo "ok   examples/cube's player build says its harness is out, and refuses --golden warp before it draws"
    else
        grep -E '^FAIL|^harness|^golden-png|^cube: ' tests/out/cube-player-golden.log | cut -c1-160
        echo "FAIL examples/cube's player build with --golden warp: the run's status is $code, or it did not refuse before it drew"
        failed=1
    fi
else
    failed=1
fi

step "the web leg: built debug and release, and run in every headless browser present"
if ! command -v emcc >/dev/null 2>&1; then
    echo "skip no emcc on PATH (run from an interactive UCRT64 shell, bash -lic)"
elif ! buildWeb debug || ! buildWeb release || ! buildCubeWeb debug || ! buildCubeWeb release; then
    failed=1
elif ! command -v node >/dev/null 2>&1; then
    echo "ok   built the tests and examples/cube for the web, debug and release"
    echo "skip no node on PATH, so no browser run"
else
    # A release build's JS that still names emscripten's `UTF8ToString` was never run through Closure: a root manifest's
    # `"release": { "closure": false }` would do that, and the release legs would test nothing of what a game ships.
    for js in tests/out/web-release/graphicstests.js tests/out/cube-web-release/cube.js; do
        if grep -q 'UTF8ToString' "$js"; then
            echo "FAIL $js still names UTF8ToString, so Closure never ran over it"
            failed=1
        else
            echo "ok   Closure ran over $js"
        fi
    done
    if browsers="$(node tools/browsers.mjs run 2>/dev/null)"; then
        n=0
        cft=0
        while IFS= read -r browser; do
            n=$((n + 1))
            name="${browser##*[/\\]}"
            gpu="$(runGolden "$browser")"
            flip="$(runFlip "$browser")"
            flags="$(browserFlags "$browser" | tr '\n' ' ')"
            # Every web leg holds the cube to a golden: its software GPU's byte for byte, or, on its own GPU, one by FLIP.
            if [ -z "$gpu" ] && [ -z "$flip" ]; then
                echo "FAIL $name runs on its own GPU and holds the cube to no golden"
                failed=1
            fi
            # Each browser runs a debug build, then a release build, each held to the same goldens.
            for mode in debug release; do
                echo "-- kama run, $browser, $mode${flags:+ ${flags% }}${gpu:+, --golden $gpu}"
                runKama "$browser" "$gpu" "tests/out/run-web-$n-$mode.log" "$mode" || failed=1
                goldensHeld "tests/out/run-web-$n-$mode.log" "$gpu" "$name, $mode"
                refusalsPrinted "tests/out/run-web-$n-$mode.log" "$name, $mode"
                builtAs "tests/out/run-web-$n-$mode.log" "$mode" "kama run, $name, $mode"
                echo "-- kama run, $browser, $mode: examples/cube on #canvas for $CUBE_FRAMES frames${gpu:+, --golden $gpu}${flip:+, --flip-against $flip}"
                runCubeKama "$browser" "$gpu" "tests/out/run-cube-web-$n-$mode.log" "$mode" "$flip" || failed=1
                cubeHeld "tests/out/run-cube-web-$n-$mode.log" "$gpu" "$name, $mode" "$flip"
                builtAs "tests/out/run-cube-web-$n-$mode.log" "$mode" "examples/cube, kama run, $name, $mode"
            done
            # The pinned Chrome for Testing is the web's SwiftShader leg (decided with the owner on 2026-11-14): one that
            # ran naming no software GPU passed on its hardware, comparing nothing.
            if [ "$(browserKind "$browser")" = chrome-for-testing ]; then
                cft=1
                if [ "$gpu" = swiftshader ]; then
                    echo "ok   the pinned Chrome for Testing compared SwiftShader's goldens"
                else
                    echo "FAIL the pinned Chrome for Testing ran naming '$gpu', not swiftshader, so it compared no SwiftShader golden"
                    failed=1
                fi
            fi
        done <<< "$browsers"
        [ "$cft" = 1 ] || echo "skip no Chrome for Testing pinned under ~/browsers, so no leg compared SwiftShader's goldens"

        # A leg whose device never opens ends as a failed run that says why, with its last lines, never a panic: a browser
        # that offers no fallback adapter (Edge, an installed Chrome) asked for WARP refuses the adapter, so no device opens.
        echo
        echo "== a leg whose device never opens fails cleanly, saying why"
        bare=""
        while IFS= read -r browser; do
            if [ -z "$(runGolden "$browser")" ]; then bare="$browser"; break; fi
        done <<< "$browsers"
        if [ -z "$bare" ]; then
            echo "skip no browser that offers no fallback adapter (Edge or Chrome installed)"
        else
            runKama "$bare" warp tests/out/no-device.log debug > /dev/null && code=0 || code=$?
            if [ "$code" != 0 ] \
                    && grep -q '^FAIL an adapter for the GPU cases: refused: ' tests/out/no-device.log \
                    && grep -qx 'FAIL a device for the GPU cases: none was opened, so no GPU case ran' tests/out/no-device.log \
                    && grep -qx 'goldens: 0 declared, 0 matched, on warp' tests/out/no-device.log \
                    && grep -q '^graphics tests: [0-9]* cases, [0-9]* failed$' tests/out/no-device.log \
                    && ! grep -qx 'gpu cases: all run' tests/out/no-device.log \
                    && ! grep -q '^golden-png ' tests/out/no-device.log; then
                echo "ok   ${bare##*[/\\]} asked for WARP opens no device, and the run fails saying so, with its last lines"
            else
                grep -E '^FAIL|^goldens:|^graphics tests:|^gpu cases|panic' tests/out/no-device.log | cut -c1-160 | tail -8
                echo "FAIL ${bare##*[/\\]} asked for WARP: the run's status is $code, or it did not end saying why with its last lines"
                failed=1
            fi
        fi
    else
        echo "skip no browser for kama run (Edge or Chrome installed, Firefox or Chrome for Testing pinned under ~/browsers; or set KAMA_BROWSER)"
    fi
fi

step "examples/cube as a player gets it: its harness left out (--define CUBE_PLAYER), run, and its web code held to its record"
# The ratchet (GFX-1's part 6, step 4; kyoten's rendering.md § Decided, 2026-11-20): the player's web build, release, its
# wasm plus its JS at brotli quality 11, held to examples/cube/web-size.json (tools/web-size.mjs). Above the record it
# fails, and raising the record takes a written reason (tools/update-web-size.sh "<why>"); below it, it passes and says to
# lower it. The build measured is run once in a player's browser, so it is one that draws.
if ! command -v emcc >/dev/null 2>&1 || ! command -v node >/dev/null 2>&1; then
    echo "skip no emcc or node on PATH, so the player's build is neither built nor measured"
elif ! buildCubePlayerWeb; then
    failed=1
else
    if grep -q 'UTF8ToString' tests/out/cube-player-web/cube.js; then
        echo "FAIL tests/out/cube-player-web/cube.js still names UTF8ToString, so Closure never ran over it"
        failed=1
    else
        echo "ok   Closure ran over tests/out/cube-player-web/cube.js"
    fi
    if sizes="$(measureCubePlayer)"; then
        read -r wasmBytes jsBytes <<< "$sizes"
        said="$(node tools/web-size.mjs check "$CUBE_RECORD" "$wasmBytes" "$jsBytes" "$(emccVersion)")" && code=0 || code=$?
        echo "${said:0:5}examples/cube as a player gets it: ${said:5}"
        [ "$code" = 0 ] || failed=1
    else
        echo "FAIL examples/cube's player build could not be measured: $sizes"
        failed=1
    fi
    # A player's browser: Edge or Chrome as installed, else the first browser there is.
    player=""
    if browsers="$(node tools/browsers.mjs run 2>/dev/null)"; then
        while IFS= read -r browser; do
            case "$(browserKind "$browser")" in edge|chrome) player="$browser"; break ;; esac
        done <<< "$browsers"
        [ -n "$player" ] || player="$(head -1 <<< "$browsers")"
    fi
    if [ -z "$player" ]; then
        echo "skip no browser for kama run, so the player's build is measured and not run"
    else
        echo "-- kama run, $player, release, --define CUBE_PLAYER: examples/cube on #canvas for $CUBE_FRAMES frames"
        runCubePlayerKama "$player" tests/out/run-cube-player.log || failed=1
        cubeHeld tests/out/run-cube-player.log "" "the player's build, ${player##*[/\\]}" ""
        builtAs tests/out/run-cube-player.log release "examples/cube's player build, ${player##*[/\\]}"
        if grep -qx 'harness: out' tests/out/run-cube-player.log; then
            echo "ok   examples/cube's player build, run, says its harness is out"
        else
            echo "FAIL examples/cube's player build, run, never said \"harness: out\", so the run was another build"
            failed=1
        fi
    fi
fi

if grep -qs '^golden-png ' tests/out/run-*.log; then
    echo
    echo "FAIL some frames differ from their goldens, or have none: run tools/update-goldens.sh, then review the diff"
    failed=1
fi
if grep -qs '^frame-png ' tests/out/run-*.log; then
    echo
    echo "FAIL some frames drawn on a player's GPU are past FLIP's limits: their frame-png lines show them"
    failed=1
fi

echo
if [ "$failed" = 0 ]; then echo "test: all passed"; else echo "test: FAILED" >&2; fi
exit "$failed"
