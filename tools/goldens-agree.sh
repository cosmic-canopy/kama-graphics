#!/usr/bin/env bash
# tools/goldens-agree.sh <dir> — whether the legs that printed frames for tools/update-goldens.sh agree, one problem a
# line, exit 1 when there is any. A golden is one software GPU's picture, the same on every leg that names that GPU
# (natively and in Firefox, WARP draws the same bytes), so for each test a frame was printed for, every leg that ran on
# its GPU must have printed that same frame: not another, not a match with the golden, and not nothing.
#
# <dir> holds what update-goldens.sh collected, one record a line:
#   ran       <leg> <gpu>                   a leg that ran
#   verdicts  <leg> ok|FAIL <test> <gpu>    a golden case's verdict on that leg
#   lines     <leg> <test> <gpu> <base64>   a frame printed
# tools/test.sh holds this to crafted records, so each refusal is tested.
set -euo pipefail
dir="$1"
problems="$(awk '
    FILENAME ~ /ran$/      { legs[$2] = legs[$2] " " $1; next }
    FILENAME ~ /verdicts$/ { if ($2 == "ok") matched[$1 " " $3 " " $4] = 1; next }
    {
        key = $2 " " $3
        if ($2 !~ /^[a-z0-9]+(-[a-z0-9]+)*$/ || $3 !~ /^[a-z0-9]+(-[a-z0-9]+)*$/) { print "a line names \"" key "\", not a golden"; next }
        if ((key in frame) && frame[key] != $4) print key ": " by[key] " and " $1 " printed different frames"
        if (!(key in frame)) { frame[key] = $4; by[key] = $1; keys[key] = 1 }
        printed[$1 " " key] = 1
    }
    END {
        for (key in keys) {
            split(key, k, " ")
            n = split(legs[k[2]], ls, " ")
            for (i = 1; i <= n; i++) {
                if ((ls[i] " " key) in printed) continue
                if ((ls[i] " " key) in matched) print key ": " ls[i] " matched the golden, and " by[key] " printed a frame"
                else print key ": " ls[i] " ran on " k[2] " and printed no frame for it"
            }
        }
    }
' "$dir/ran" "$dir/verdicts" "$dir/lines" | sort)"
if [ -n "$problems" ]; then
    printf '%s\n' "$problems"
    exit 1
fi
