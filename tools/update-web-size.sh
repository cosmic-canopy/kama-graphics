#!/usr/bin/env bash
# tools/update-web-size.sh — writes examples/cube's web-size record, run on purpose with the reason for its new size
# (GFX-1's part 6, step 4; kyoten's rendering.md § Decided, 2026-11-20). The gate never writes it: tools/test.sh builds the
# cube as a player gets it (--define CUBE_PLAYER, its harness left out), measures its wasm plus its JS at brotli quality
# 11 (tools/web-size.mjs), and fails when that is above the record. This builds and measures the same way, as
# tools/legs.sh says, and appends the measurement to examples/cube/web-size.json with the date, the kama it was built
# with and the reason. A raise is never refused, and takes its reason; so does a drop, so the record keeps identifying
# growth. Review the change in its diff, then run tools/test.sh, which must pass, before committing.
#
#   tools/update-web-size.sh "<why>"
#
# It needs emcc and node, as the gate's web leg does (run it from an interactive UCRT64 shell on Windows, bash -lic).
set -euo pipefail
. "$(dirname "$0")/legs.sh"

why="${1:-}"
if [ -z "${why// /}" ]; then
    echo "update-web-size: a record takes a written reason: tools/update-web-size.sh \"<why>\"" >&2
    exit 1
fi
if ! command -v emcc >/dev/null 2>&1 || ! command -v node >/dev/null 2>&1; then
    echo "update-web-size: needs emcc and node on PATH (run from an interactive UCRT64 shell, bash -lic)" >&2
    exit 1
fi
"$KAMA" pkg install examples/cube/kama.json > /dev/null
buildCubePlayerWeb
read -r wasmBytes jsBytes <<< "$(measureCubePlayer)"
version="$("$KAMA" --version | tr -d '\r' | sed 's/^kama //')"
node tools/web-size.mjs record "$CUBE_RECORD" "$wasmBytes" "$jsBytes" "$version" "$(emccVersion)" "$why"
