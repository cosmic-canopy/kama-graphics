#!/usr/bin/env bash
# tools/test.sh — @kama/graphics' gate: the roadmap and the feature map held to their rules, the library and its tests
# checked, and the tests program run natively, debug and release, and built for the web, debug and release, and run in
# every headless browser present, every frame held to its software GPU's golden where the leg names one (tools/legs.sh).
#
#   tools/test.sh
#
# Run it from msys2 UCRT64 on Windows (bash -lic, so emcc and node are on PATH for the web leg), or any shell elsewhere.
# The web leg is built when `emcc` is on PATH and run, headless, under `kama run --target WASM` in every browser
# tools/browsers.mjs finds: Edge and Chrome as installed, the pinned Firefox and the pinned Chrome for Testing
# (KAMA_BROWSER names one). Each part is skipped, and says so, without what it needs.
#
# The goldens (tests/goldens/<test>/<gpu>.png) are never written here. A frame that differs from its golden, or has none,
# fails its leg and is printed as a `golden-png` line; tools/update-goldens.sh, run on purpose, writes those, and the
# change is reviewed in its diff.
set -euo pipefail
. "$(dirname "$0")/legs.sh"

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
# material, rendered twice (tests/src/shaders.kama), and one directional light at its own target, drawn twice
# (tests/src/lights.kama). Each refusal printed once, on every leg.
refusalsPrinted() {
    local log="$1" leg="$2" renders adds materials lights
    renders="$(grep -c '@kama/graphics: render drew nothing' "$log" || true)"
    adds="$(grep -c '@kama/graphics: add refused' "$log" || true)"
    materials="$(grep -c '@kama/graphics: a material was refused' "$log" || true)"
    lights="$(grep -c '@kama/graphics: a directional light sits at its own target' "$log" || true)"
    if [ "$renders" = 1 ] && [ "$adds" = 5 ] && [ "$materials" = 1 ] && [ "$lights" = 1 ]; then
        echo "ok   each refused misuse was printed once, and none by the renderer told not to print ($leg)"
    else
        echo "FAIL ($leg) the refused misuses printed: ${renders} render line(s), not 1, ${adds} add line(s), not 5, ${materials} material line(s), not 1, and ${lights} light line(s), not 1"
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

step "kama check"
"$KAMA" pkg install kama.json > /dev/null
"$KAMA" check kama.json || failed=1
"$KAMA" pkg install tests/kama.json > /dev/null
"$KAMA" check tests/kama.json || failed=1

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

step "the web leg: built debug and release, and run in every headless browser present"
if ! command -v emcc >/dev/null 2>&1; then
    echo "skip no emcc on PATH (run from an interactive UCRT64 shell, bash -lic)"
elif ! buildWeb debug || ! buildWeb release; then
    failed=1
elif ! command -v node >/dev/null 2>&1; then
    echo "ok   built tests/out/web-debug/graphicstests.html and tests/out/web-release/graphicstests.html"
    echo "skip no node on PATH, so no browser run"
else
    # A release build's JS that still names emscripten's `UTF8ToString` was never run through Closure: a root manifest's
    # `"release": { "closure": false }` would do that, and the release legs would test nothing of what a game ships.
    if grep -q 'UTF8ToString' tests/out/web-release/graphicstests.js; then
        echo "FAIL tests/out/web-release/graphicstests.js still names UTF8ToString, so Closure never ran over it"
        failed=1
    else
        echo "ok   Closure ran over tests/out/web-release/graphicstests.js"
    fi
    if browsers="$(node tools/browsers.mjs run 2>/dev/null)"; then
        n=0
        cft=0
        while IFS= read -r browser; do
            n=$((n + 1))
            name="${browser##*[/\\]}"
            gpu="$(runGolden "$browser")"
            flags="$(browserFlags "$browser" | tr '\n' ' ')"
            # Each browser runs a debug build, then a release build, each held to the same goldens.
            for mode in debug release; do
                echo "-- kama run, $browser, $mode${flags:+ ${flags% }}${gpu:+, --golden $gpu}"
                runKama "$browser" "$gpu" "tests/out/run-web-$n-$mode.log" "$mode" || failed=1
                goldensHeld "tests/out/run-web-$n-$mode.log" "$gpu" "$name, $mode"
                refusalsPrinted "tests/out/run-web-$n-$mode.log" "$name, $mode"
                builtAs "tests/out/run-web-$n-$mode.log" "$mode" "kama run, $name, $mode"
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

if grep -qs '^golden-png ' tests/out/run-*.log; then
    echo
    echo "FAIL some frames differ from their goldens, or have none: run tools/update-goldens.sh, then review the diff"
    failed=1
fi

echo
if [ "$failed" = 0 ]; then echo "test: all passed"; else echo "test: FAILED" >&2; fi
exit "$failed"
