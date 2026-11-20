# tools/legs.sh — the legs @kama/graphics' tests run on, sourced by tools/test.sh and tools/update-goldens.sh, so a
# golden is written from exactly the runs the gate then holds it to.
#
# Each leg names its software GPU (kyoten's rendering.md § Decided, GFX-1's part 1, question 3), since the adapter cannot
# say which it is: WARP natively on Windows and as Firefox's fallback adapter (`--golden warp`), SwiftShader in the pinned
# Chrome for Testing (`--golden swiftshader`), which Chromium offers WebGPU only when its command line asks: every browser
# runs under `kama run`, and tools/browsers.mjs says what each is started with (decided with the owner on 2026-11-14).
# A leg with no software GPU names none, and compares no golden:
#   - Edge and an installed Chrome, which run as a player's do, on their real GPU: the web's hardware leg;
#   - natively on macOS, where Metal has none;
#   - natively on Linux, until lavapipe is measured.
#
# It needs kama ($KAMA, else `kama` on PATH, else ../kama's build) and, natively, wgpu-native's SDK: $KAMA_WGPU_DIR, else
# this package's third_party/wgpu/<platform>, else @kama/gpu's beside it (../kama-gpu, which the tests depend on by path).
# On Windows it also needs DXC's dxcompiler.dll, found the same way ($KAMA_DXC_DIR, else third_party/dxc/<platform> here
# or in ../kama-gpu, which @kama/gpu's tools/fetch-dxc.sh fills): with it Direct3D 12 compiles shaders with DXC, as
# Firefox's WebGPU does, so WARP draws one picture on both its legs (kyoten's rendering.md § Decided, DXC; @kama/gpu's
# AGENTS.gpu.md item 16).

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
case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*)
        if [ -z "${KAMA_DXC_DIR:-}" ]; then
            if [ -f "$ROOT/third_party/dxc/$PLAT/dxcompiler.dll" ]; then KAMA_DXC_DIR="$ROOT/third_party/dxc/$PLAT"
            else KAMA_DXC_DIR="$ROOT/../kama-gpu/third_party/dxc/$PLAT"
            fi
        fi
        [ -f "$KAMA_DXC_DIR/dxcompiler.dll" ] || {
            echo "legs: no dxcompiler.dll at $KAMA_DXC_DIR (set KAMA_DXC_DIR, or fetch it with ../kama-gpu/tools/fetch-dxc.sh)" >&2
            exit 1
        }
        export KAMA_DXC_DIR
        export PATH="$KAMA_DXC_DIR:$PATH"
        ;;
esac
mkdir -p tests/out

# A browser run, bounded where `timeout` exists: `kama run` has no time limit, and a browser that never asks for the page
# waits for ever (kyoten's KY-53).
bounded() { if command -v timeout >/dev/null 2>&1; then timeout 300 "$@"; else "$@"; fi; }

# What a browser is (firefox, chrome-for-testing, edge or chrome), and what `kama run` starts it with, one word a line
# and nothing for most (tools/browsers.mjs).
browserKind() { node tools/browsers.mjs kind "$1" | tr -d '\r'; }
browserFlags() { node tools/browsers.mjs flags "$1" | tr -d '\r'; }

# The software GPU each leg names, "" for none. The pinned Chrome for Testing names SwiftShader, which its flags offer;
# a run whose flags do not offer it fails on the adapter, never comparing a hardware frame.
nativeGolden() { case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*) echo warp ;; *) echo "" ;; esac; }
runGolden() {
    case "$(browserKind "$1")" in
        firefox) echo warp ;;
        chrome-for-testing) echo swiftshader ;;
        *) echo "" ;;
    esac
}

# The software golden a leg on a player's GPU holds examples/cube's frame to by FLIP (GFX-1's part 6, step 3; kyoten's
# rendering.md § Decided, 2026-11-20): natively on Windows, WARP's, at the same 640 x 400; a Chromium on its own GPU
# (Edge, an installed Chrome), at Chrome for Testing's scale of 1.5, SwiftShader's, the web's, so every web leg on every
# operating system can be held to it. "" for a leg with none: natively off Windows until its software GPU's golden is
# measured (lavapipe on Linux), and every leg already on a software GPU.
nativeFlip() { nativeGolden; }
runFlip() {
    case "$(browserKind "$1")" in
        edge|chrome) echo swiftshader ;;
        *) echo "" ;;
    esac
}

buildNative() {
    local mode="$1" flag=""
    [ "$mode" = release ] && flag="--release"
    if ! "$KAMA" build tests/kama.json $flag -o "tests/out/native-$mode/graphicstests$EXE" > "tests/out/build-$mode.log" 2>&1; then
        tail -20 "tests/out/build-$mode.log"
        return 1
    fi
}

# The web build, debug unless the first argument says release: a wasm release runs Closure over the page's JS since kama
# 0.9.966 (KR-289), and the gate runs both (kyoten's rendering.md § Decided, 2026-11-17).
buildWeb() {
    local mode="${1:-debug}" flag=""
    [ "$mode" = release ] && flag="--release"
    if ! "$KAMA" build tests/kama.json $flag --target WASM -o "tests/out/web-$mode/graphicstests.html" \
            > "tests/out/build-web-$mode.log" 2>&1; then
        tail -20 "tests/out/build-web-$mode.log"
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
    local browser="$1" gpu="$2" log="$3" mode="${4:-debug}" args=() flags=() f build=""
    while IFS= read -r f; do [ -n "$f" ] && flags+=("$f"); done < <(browserFlags "$browser")
    [ -n "$gpu" ] && args=(-- --golden "$gpu")
    [ "$mode" = release ] && build="--release"
    KAMA_BROWSER="$browser" bounded "$KAMA" run tests/kama.json $build --target WASM --headless ${flags[@]+"${flags[@]}"} \
        ${args[@]+"${args[@]}"} < /dev/null 2>&1 | tr -d '\r' | tee "$log"
}

# examples/cube (GFX-1's part 6, step 2): a lit cube in a window, its last frame read back after CUBE_FRAMES frames and,
# on a leg naming a software GPU, held to its golden, examples/cube/goldens/<gpu>.png. It names its GPU as the tests do.
CUBE_FRAMES=60

buildCube() {
    local mode="$1" flag=""
    [ "$mode" = release ] && flag="--release"
    if ! "$KAMA" build examples/cube/kama.json $flag -o "tests/out/cube-native-$mode/cube$EXE" > "tests/out/build-cube-$mode.log" 2>&1; then
        tail -20 "tests/out/build-cube-$mode.log"
        return 1
    fi
}

buildCubeWeb() {
    local mode="$1" flag=""
    [ "$mode" = release ] && flag="--release"
    if ! "$KAMA" build examples/cube/kama.json $flag --target WASM -o "tests/out/cube-web-$mode/cube.html" \
            > "tests/out/build-cube-web-$mode.log" 2>&1; then
        tail -20 "tests/out/build-cube-web-$mode.log"
        return 1
    fi
}

runCube() {
    local mode="$1" gpu="$2" log="$3" flip="${4:-}" args=(--frames "$CUBE_FRAMES")
    [ -n "$gpu" ] && args+=(--golden "$gpu")
    [ -n "$flip" ] && args+=(--flip-against "$flip")
    "tests/out/cube-native-$mode/cube$EXE" "${args[@]}" < /dev/null 2>&1 | tr -d '\r' | tee "$log"
}

runCubeKama() {
    local browser="$1" gpu="$2" log="$3" mode="${4:-debug}" flip="${5:-}" args=(-- --frames "$CUBE_FRAMES") flags=() f build=""
    while IFS= read -r f; do [ -n "$f" ] && flags+=("$f"); done < <(browserFlags "$browser")
    [ -n "$gpu" ] && args+=(--golden "$gpu")
    [ -n "$flip" ] && args+=(--flip-against "$flip")
    [ "$mode" = release ] && build="--release"
    KAMA_BROWSER="$browser" bounded "$KAMA" run examples/cube/kama.json $build --target WASM --headless \
        ${flags[@]+"${flags[@]}"} "${args[@]}" < /dev/null 2>&1 | tr -d '\r' | tee "$log"
}

# examples/cube as a player gets it (GFX-1's part 6, step 4; kyoten's rendering.md § Decided, 2026-11-20): the same source
# at --release with --define CUBE_PLAYER, which leaves its harness out (src/check.kama's goldens, PNG and FLIP). Its web
# build is what the ratchet measures (tools/web-size.mjs): its wasm plus its JS at brotli quality 11, held to the record
# CUBE_RECORD, which tools/update-web-size.sh writes. The goldens stay in it as assets, and emscripten's file packager
# with them, since kama packs a manifest's assets into every build (kyoten's KY-63); the record says so.
CUBE_RECORD=examples/cube/web-size.json

buildCubePlayerWeb() {
    if ! "$KAMA" build examples/cube/kama.json --release --target WASM --define CUBE_PLAYER \
            -o tests/out/cube-player-web/cube.js > tests/out/build-cube-player-web.log 2>&1; then
        tail -20 tests/out/build-cube-player-web.log
        return 1
    fi
}

buildCubePlayerNative() {
    if ! "$KAMA" build examples/cube/kama.json --define CUBE_PLAYER -o "tests/out/cube-player-native/cube$EXE" \
            > tests/out/build-cube-player-native.log 2>&1; then
        tail -20 tests/out/build-cube-player-native.log
        return 1
    fi
}

# "<wasm> <js>", each in bytes after brotli.
measureCubePlayer() { node tools/web-size.mjs measure tests/out/cube-player-web/cube.wasm tests/out/cube-player-web/cube.js; }

# The player's build run once in a browser under kama run, as a player's page runs it, naming no golden.
runCubePlayerKama() {
    local browser="$1" log="$2" flags=() f
    while IFS= read -r f; do [ -n "$f" ] && flags+=("$f"); done < <(browserFlags "$browser")
    KAMA_BROWSER="$browser" bounded "$KAMA" run examples/cube/kama.json --release --target WASM --define CUBE_PLAYER \
        --headless ${flags[@]+"${flags[@]}"} -- --frames "$CUBE_FRAMES" < /dev/null 2>&1 | tr -d '\r' | tee "$log"
}

# The emcc a web build is made with: a build's bytes are its toolchain's as much as its source's, so the record keeps an
# entry per emcc.
emccVersion() { emcc -dumpversion 2>/dev/null | tr -d '\r'; }
