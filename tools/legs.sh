# tools/legs.sh — the legs @kama/graphics' tests run on, sourced by tools/test.sh and tools/update-goldens.sh, so a
# golden is written from exactly the runs the gate then holds it to.
#
# Each leg names its software GPU (kyoten's rendering.md § Decided, GFX-1's part 1, question 3), since the adapter cannot
# say which it is: WARP natively on Windows and as Firefox's fallback adapter (`--golden warp`), SwiftShader in Chromium
# through the driver (`--golden swiftshader`). A leg with no software GPU names none, and compares no golden:
#   - Chromium under `kama run`, which offers WebGPU its fallback adapter only when its command line asks, and
#     `kama run` passes a browser none of our flags (kyoten's KY-57); the driver passes them;
#   - natively on macOS, where Metal has none;
#   - natively on Linux, until lavapipe is measured.
#
# It needs kama ($KAMA, else `kama` on PATH, else ../kama's build) and, natively, wgpu-native's SDK: $KAMA_WGPU_DIR, else
# this package's third_party/wgpu/<platform>, else @kama/gpu's beside it (../kama-gpu, which the tests depend on by path).

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*) PLAT="${MSYSTEM:-$(uname -s)}-$(uname -m)"; EXE=.exe ;;
    *) PLAT="$(uname -s)-$(uname -m)"; EXE= ;;
esac
if [ -n "${KAMA:-}" ]; then :
elif command -v kama >/dev/null 2>&1; then KAMA=kama
elif [ -x "$ROOT/../kama/out/$PLAT/kama$EXE" ]; then KAMA="$ROOT/../kama/out/$PLAT/kama$EXE"
else echo "legs: no kama (set KAMA)" >&2; exit 1
fi
if [ -z "${KAMA_WGPU_DIR:-}" ]; then
    if [ -d "$ROOT/third_party/wgpu/$PLAT/lib" ]; then KAMA_WGPU_DIR="$ROOT/third_party/wgpu/$PLAT"
    else KAMA_WGPU_DIR="$ROOT/../kama-gpu/third_party/wgpu/$PLAT"
    fi
fi
export KAMA_WGPU_DIR
[ -d "$KAMA_WGPU_DIR/lib" ] || {
    echo "legs: no wgpu-native SDK at $KAMA_WGPU_DIR (set KAMA_WGPU_DIR, or fetch one with ../kama/tools/fetch-webgpu.sh)" >&2
    exit 1
}
# the native leg links wgpu_native dynamically: the loader finds it on PATH (Windows) or the rpath kama sets
export PATH="$KAMA_WGPU_DIR/lib:$PATH"
mkdir -p tests/out

# A browser run, bounded where `timeout` exists: `kama run` has no time limit, and a browser that never asks for the page
# waits for ever (kyoten's KY-53).
bounded() { if command -v timeout >/dev/null 2>&1; then timeout 300 "$@"; else "$@"; fi; }

# The software GPU each leg names, "" for none.
nativeGolden() { case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*) echo warp ;; *) echo "" ;; esac; }
runGolden() { local name="${1##*[/\\]}"; if [[ "${name,,}" == *firefox* ]]; then echo warp; else echo ""; fi; }
driverGolden() { echo swiftshader; }

buildNative() {
    local mode="$1" flag=""
    [ "$mode" = release ] && flag="--release"
    if ! "$KAMA" build tests/kama.json $flag -o "tests/out/native-$mode/graphicstests$EXE" > "tests/out/build-$mode.log" 2>&1; then
        tail -20 "tests/out/build-$mode.log"
        return 1
    fi
}

buildWeb() {
    if ! "$KAMA" build tests/kama.json --target WASM -o tests/out/web/graphicstests.html > tests/out/build-web.log 2>&1; then
        tail -20 tests/out/build-web.log
        return 1
    fi
}

# Each run prints the program's output and keeps it in a log; its status is the program's.
runNative() {
    local mode="$1" gpu="$2" log="$3" args=()
    [ -n "$gpu" ] && args=(--golden "$gpu")
    "tests/out/native-$mode/graphicstests$EXE" ${args[@]+"${args[@]}"} < /dev/null 2>&1 | tr -d '\r' | tee "$log"
}

runKama() {
    local browser="$1" gpu="$2" log="$3" args=()
    [ -n "$gpu" ] && args=(-- --golden "$gpu")
    KAMA_BROWSER="$browser" bounded "$KAMA" run tests/kama.json --target WASM --headless ${args[@]+"${args[@]}"} < /dev/null 2>&1 \
        | tr -d '\r' | tee "$log"
}

runDriver() {
    local browser="$1" gpu="$2" log="$3" query=""
    [ -n "$gpu" ] && query="?arg=--golden&arg=$gpu"
    node tools/webtest.mjs tests/out/web "graphicstests.html$query" --browser "$browser" < /dev/null 2>&1 | tr -d '\r' | tee "$log"
}
