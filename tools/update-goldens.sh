#!/usr/bin/env bash
# tools/update-goldens.sh — writes the goldens the tests and examples/cube print, run on purpose (kyoten's rendering.md §
# Decided, GFX-1's part 1, question 3). Neither ever writes a golden: a frame that differs from its golden, or has none,
# is printed as one line, `golden-png <test> <gpu> <base64 PNG>`, because a page in a browser cannot write a file. This
# runs every leg that names a software GPU (tools/legs.sh), as tools/test.sh does, collects those lines, and writes each
# frame: the tests' to tests/goldens/<test>/<gpu>.png, and examples/cube's to examples/cube/goldens/<gpu>.png. Then
# review the change in its diff, look at each image, and run tools/test.sh, which must pass, before committing.
#
#   tools/update-goldens.sh
#
# It refuses, writing nothing at all, when the legs of one software GPU disagree, the tests' or the cube's: two that
# printed different frames for one test (natively and in Firefox, WARP draws the same bytes), or one that printed a frame
# while another matched the golden or never reached it. A golden is one GPU's picture, the same on every leg that names
# it.
set -euo pipefail
. "$(dirname "$0")/legs.sh"

work=tests/out/update-goldens
rm -rf "$work"
mkdir -p "$work/tests" "$work/cube"
for records in "$work/tests" "$work/cube"; do
    : > "$records/lines"     # <leg> <test> <gpu> <base64>, one a frame printed
    : > "$records/ran"       # <leg> <gpu>, one a leg that ran
    : > "$records/verdicts"  # <leg> ok|FAIL <test> <gpu>, one a golden case's verdict
done

# One leg's run into `records`: what it printed and what its golden cases said. A leg whose run fails is expected here (a
# frame that differs fails), so its status is not this script's.
collect() {
    local records="$1" leg="$2" gpu="$3" log="$4"
    echo "$leg $gpu" >> "$records/ran"
    grep '^golden-png ' "$log" | awk -v leg="$leg" '{ print leg, $2, $3, $4 }' >> "$records/lines" || true
    grep -E '^(ok   |FAIL )golden [a-z0-9-]+ on [a-z0-9]+' "$log" \
        | sed -E 's/^(ok|FAIL) +golden ([a-z0-9-]+) on ([a-z0-9]+).*/\1 \2 \3/' | awk -v leg="$leg" '{ print leg, $0 }' \
        >> "$records/verdicts" || true
}

gpu="$(nativeGolden)"
if [ -n "$gpu" ]; then
    echo "== native, debug, --golden $gpu"
    buildNative debug
    runNative debug "$gpu" "$work/native.log" > /dev/null || true
    collect "$work/tests" native "$gpu" "$work/native.log"
    echo "== examples/cube, native, debug, --golden $gpu"
    "$KAMA" pkg install examples/cube/kama.json > /dev/null
    buildCube debug
    runCube debug "$gpu" "$work/cube-native.log" > /dev/null || true
    collect "$work/cube" native "$gpu" "$work/cube-native.log"
else
    echo "skip natively: this platform names no software GPU yet"
fi

if command -v emcc >/dev/null 2>&1 && command -v node >/dev/null 2>&1; then
    buildWeb
    "$KAMA" pkg install examples/cube/kama.json > /dev/null
    if browsers="$(node tools/browsers.mjs run 2>/dev/null)"; then
        n=0
        while IFS= read -r browser; do
            n=$((n + 1))
            gpu="$(runGolden "$browser")"
            [ -n "$gpu" ] || continue
            echo "== kama run, $browser, --golden $gpu"
            runKama "$browser" "$gpu" "$work/run-$n.log" > /dev/null || true
            collect "$work/tests" "kama-run-$n" "$gpu" "$work/run-$n.log"
            echo "== examples/cube, kama run, $browser, --golden $gpu"
            runCubeKama "$browser" "$gpu" "$work/cube-run-$n.log" > /dev/null || true
            collect "$work/cube" "kama-run-$n" "$gpu" "$work/cube-run-$n.log"
        done <<< "$browsers"
    fi
else
    echo "skip the web legs: no emcc or node on PATH (run from an interactive UCRT64 shell, bash -lic)"
fi

# Every (test, gpu) printed, with each leg of that gpu held to printing the same frame for it: the tests' and the cube's
# each among their own legs.
problems="$(tools/goldens-agree.sh "$work/tests" || true)"
cubeProblems="$(tools/goldens-agree.sh "$work/cube" || true)"
if [ -n "$cubeProblems" ]; then problems="$(printf '%s\n%s' "$problems" "$cubeProblems" | sed '/^$/d')"; fi

if [ -n "$problems" ]; then
    echo
    echo "update-goldens: refused, writing nothing: the legs of one software GPU disagree:" >&2
    printf '%s\n' "$problems" | sed 's/^/    /' >&2
    exit 1
fi

if [ ! -s "$work/tests/lines" ] && [ ! -s "$work/cube/lines" ]; then
    echo
    echo "update-goldens: every golden matched on every leg; nothing to write"
    exit 0
fi

echo
awk '!seen[$2 " " $3]++ { print $2, $3, $4 }' "$work/tests/lines" | while read -r test gpu text; do
    mkdir -p "tests/goldens/$test"
    printf '%s' "$text" | base64 -d > "tests/goldens/$test/$gpu.png"
    echo "wrote tests/goldens/$test/$gpu.png ($(wc -c < "tests/goldens/$test/$gpu.png" | tr -d ' ') bytes)"
done
# The cube prints its frames as test `cube`; anything else on its legs is not the cube's.
awk '!seen[$2 " " $3]++ { print $2, $3, $4 }' "$work/cube/lines" | while read -r test gpu text; do
    if [ "$test" != cube ]; then echo "update-goldens: examples/cube printed a frame for '$test', not cube; not written" >&2; continue; fi
    printf '%s' "$text" | base64 -d > "examples/cube/goldens/$gpu.png"
    echo "wrote examples/cube/goldens/$gpu.png ($(wc -c < "examples/cube/goldens/$gpu.png" | tr -d ' ') bytes)"
done
echo
git status --short -- tests/goldens examples/cube/goldens
echo
echo "update-goldens: review the change (git diff --stat -- tests/goldens examples/cube/goldens, and look at each image), then run tools/test.sh"
