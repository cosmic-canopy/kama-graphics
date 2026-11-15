#!/usr/bin/env bash
# tools/update-goldens.sh — writes the goldens the tests print, run on purpose (kyoten's rendering.md § Decided, GFX-1's
# part 1, question 3). The tests never write a golden: a frame that differs from its golden, or has none, is printed as
# one line, `golden-png <test> <gpu> <base64 PNG>`, because a page in a browser cannot write a file. This runs every leg
# that names a software GPU (tools/legs.sh), as tools/test.sh does, collects those lines, and writes each frame to
# tests/goldens/<test>/<gpu>.png. Then review the change in its diff, look at each image, and run tools/test.sh, which
# must pass, before committing.
#
#   tools/update-goldens.sh
#
# It refuses, writing nothing, when the legs of one software GPU disagree: two that printed different frames for one
# test (natively and in Firefox, WARP draws the same bytes), or one that printed a frame while another matched the golden
# or never reached it. A golden is one GPU's picture, the same on every leg that names it.
set -euo pipefail
. "$(dirname "$0")/legs.sh"

work=tests/out/update-goldens
rm -rf "$work"
mkdir -p "$work"
: > "$work/lines"     # <leg> <test> <gpu> <base64>, one a frame printed
: > "$work/ran"       # <leg> <gpu>, one a leg that ran
: > "$work/verdicts"  # <leg> ok|FAIL <test> <gpu>, one a golden case's verdict

# One leg's run: what it printed and what its golden cases said. A leg whose run fails is expected here (a frame that
# differs fails), so its status is not this script's.
collect() {
    local leg="$1" gpu="$2" log="$3"
    echo "$leg $gpu" >> "$work/ran"
    grep '^golden-png ' "$log" | awk -v leg="$leg" '{ print leg, $2, $3, $4 }' >> "$work/lines" || true
    grep -E '^(ok   |FAIL )golden [a-z0-9-]+ on [a-z0-9]+' "$log" \
        | sed -E 's/^(ok|FAIL) +golden ([a-z0-9-]+) on ([a-z0-9]+).*/\1 \2 \3/' | awk -v leg="$leg" '{ print leg, $0 }' \
        >> "$work/verdicts" || true
}

gpu="$(nativeGolden)"
if [ -n "$gpu" ]; then
    echo "== native, debug, --golden $gpu"
    buildNative debug
    runNative debug "$gpu" "$work/native.log" > /dev/null || true
    collect native "$gpu" "$work/native.log"
else
    echo "skip natively: this platform names no software GPU yet"
fi

if command -v emcc >/dev/null 2>&1 && command -v node >/dev/null 2>&1; then
    buildWeb
    if browsers="$(node tools/browsers.mjs run 2>/dev/null)"; then
        n=0
        while IFS= read -r browser; do
            n=$((n + 1))
            gpu="$(runGolden "$browser")"
            [ -n "$gpu" ] || continue
            echo "== kama run, $browser, --golden $gpu"
            runKama "$browser" "$gpu" "$work/run-$n.log" > /dev/null || true
            collect "kama-run-$n" "$gpu" "$work/run-$n.log"
        done <<< "$browsers"
    fi
else
    echo "skip the web legs: no emcc or node on PATH (run from an interactive UCRT64 shell, bash -lic)"
fi

# Every (test, gpu) printed, with each leg of that gpu held to printing the same frame for it.
problems="$(tools/goldens-agree.sh "$work" || true)"

if [ -n "$problems" ]; then
    echo
    echo "update-goldens: refused, writing nothing: the legs of one software GPU disagree:" >&2
    printf '%s\n' "$problems" | sed 's/^/    /' >&2
    exit 1
fi

if [ ! -s "$work/lines" ]; then
    echo
    echo "update-goldens: every golden matched on every leg; nothing to write"
    exit 0
fi

echo
awk '!seen[$2 " " $3]++ { print $2, $3, $4 }' "$work/lines" | while read -r test gpu text; do
    mkdir -p "tests/goldens/$test"
    printf '%s' "$text" | base64 -d > "tests/goldens/$test/$gpu.png"
    echo "wrote tests/goldens/$test/$gpu.png ($(wc -c < "tests/goldens/$test/$gpu.png" | tr -d ' ') bytes)"
done
echo
git status --short -- tests/goldens
echo
echo "update-goldens: review the change (git diff --stat -- tests/goldens, and look at each image), then run tools/test.sh"
