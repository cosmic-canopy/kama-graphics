#!/bin/sh
# check-features.sh — FEATURES.md, the feature map, stays complete and honest.
#
# The map is one row per feature (kyoten's graphics design pass, area 5, 2026-11-11). A row that drifts — a status
# outside the set, an example nothing schedules, a test that does not exist, a budget claimed before anything was
# measured — makes the map a wish list. So the invariants are structural:
#   1. The examples table names each example once, and each is scheduled by a live GFX row in ROADMAP.md (or `shipped`).
#   2. Every feature row has the seven cells, and its feature name is unique.
#   3. Its status is `planned`, `partial` or `built`; a `partial` row marks a built method ✓, and a `planned` one none.
#   4. Its example is a declared one, or `asked`; and every declared example is some row's.
#   5. Its test is a kebab-case name, unique, and once a method is built, something holds it by that name (GFX-1's part
#      6, step 4; kyoten's rendering.md § Decided, 2026-11-20): its golden, `tests/goldens/<test>/`, or a golden per
#      method, `tests/goldens/<test>-<method>/` where `<test>-<method>` is no other row's test; an example's own goldens,
#      `examples/<test>/goldens/`; or, for a feature that draws nothing of its own, named cases, each printed as
#      `<test>: …` or `<test>, …`. A word that merely appears somewhere in `tests/` holds nothing.
#   6. Its budget is `—` while planned, and once a method is built either the measurement it shares, `<n.n> KB, the
#      <example>'s`, equal to that example's web-size record (examples/<example>/web-size.json, its latest entry for
#      some emcc, in KB of 1,000 bytes to one decimal), or `with <example>`, naming its own example, while a live row
#      schedules it: a built feature the first example's build leaves out, measured once that example is.
set -u

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
FM="$ROOT/FEATURES.md"
RM="$ROOT/ROADMAP.md"

fail() { echo "check-features: FAIL — $1" >&2; exit 1; }

[ -f "$FM" ] || fail "no FEATURES.md"
[ -f "$RM" ] || fail "no ROADMAP.md"

ids=$(LC_ALL=C grep -oE '^\| GFX-[0-9]+ \|' "$RM" | tr -d '| ' | tr '\n' ' ')

# One pass over the tables. A table's kind is set by its header row; any line that is not a table row ends it.
rows=$(awk '
    function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
    /^\| Example \| What it is \| Row \|/ { kind = "ex"; next }
    /^\| Feature \| Known as \| Methods, best first \(needs\) \| Status \| Example \| Test \| Budget \|/ { kind = "ft"; next }
    /^\|---/ { next }
    !/^\|/ { kind = ""; next }
    kind == "ex" { n = split($0, c, "|"); print "EX\t" NR "\t" n "\t" trim(c[2]) "\t" trim(c[4]); next }
    kind == "ft" {
        n = split($0, c, "|")
        tick = (index(c[4], "✓") > 0) ? "tick" : "none"
        print "FT\t" NR "\t" n "\t" trim(c[2]) "\t" trim(c[5]) "\t" trim(c[6]) "\t" trim(c[7]) "\t" trim(c[8]) "\t" tick
    }
' "$FM")

problems=$(printf '%s\n' "$rows" | awk -F '\t' -v ids=" $ids " '
    $1 == "EX" {
        if ($3 != 5) { print "line " $2 ": the examples table has three cells a row"; next }
        if ($4 !~ /^[a-z][a-z0-9-]*$/) print "line " $2 ": example \"" $4 "\" is not a lowercase name"
        if ($4 in ex) print "line " $2 ": example \"" $4 "\" is declared twice"
        ex[$4] = 1; nex++
        if ($5 != "shipped" && index(ids, " " $5 " ") == 0)
            print "line " $2 ": example \"" $4 "\" is scheduled by " $5 ", which ROADMAP.md has no row for (a shipped row: write `shipped`)"
        if ($5 != "shipped") print "LIVE\t" $4
        next
    }
    $1 == "FT" {
        nft++
        if ($3 != 9) { print "line " $2 ": a feature row has seven cells, this one " ($3 - 2); next }
        f = $4; st = $5; eg = $6; t = $7; b = $8; tick = $9
        if (f == "") print "line " $2 ": a feature with no name"
        if (f in feat) print "line " $2 ": feature \"" f "\" is listed twice"
        feat[f] = 1
        if (st != "planned" && st != "partial" && st != "built") print "line " $2 ": status \"" st "\" is not planned, partial or built"
        if (st == "partial" && tick != "tick") print "line " $2 ": \"" f "\" is partial, so a built method is marked ✓"
        if (st == "planned" && tick == "tick") print "line " $2 ": \"" f "\" is planned, so no method is marked ✓"
        if (eg != "asked") { used[eg] = 1; want[eg] = want[eg] " " $2 }
        if (t !~ /^[a-z0-9]+(-[a-z0-9]+)*$/) print "line " $2 ": test \"" t "\" is not a kebab-case name"
        if (t in test) print "line " $2 ": test \"" t "\" is also line " test[t] "'"'"'s"
        test[t] = $2
        print "TEST\t" t
        if (st == "planned" && b != "—") print "line " $2 ": \"" f "\" is planned, so its budget is — until a measurement sets it"
        if (st != "planned" && (b == "—" || b == "")) print "line " $2 ": \"" f "\" has a built method, so its budget is the measured one"
        if (st != "planned") print "BUILT\t" $2 "\t" f "\t" t "\t" eg "\t" b
    }
    END {
        if (nex == 0) print "no examples table"
        if (nft == 0) print "no feature rows"
        for (e in want) if (!(e in ex)) print "line" want[e] ": example \"" e "\" is not declared in the examples table"
        for (e in ex) if (!(e in used)) print "example \"" e "\" is declared, and no feature row needs it"
    }
')

built=$(printf '%s\n' "$problems" | awk -F '\t' '$1 == "BUILT"')
tests=" $(printf '%s\n' "$problems" | awk -F '\t' '$1 == "TEST" { print $2 }' | tr '\n' ' ')"
live=" $(printf '%s\n' "$problems" | awk -F '\t' '$1 == "LIVE" { print $2 }' | tr '\n' ' ')"
problems=$(printf '%s\n' "$problems" | grep -v '^BUILT\|^TEST\|^LIVE' | grep .)

# Whether something holds test `$1` by its name (invariant 5).
heldBy() {
    [ -n "$(ls "$ROOT/tests/goldens/$1/"*.png 2>/dev/null)" ] && return 0
    for d in "$ROOT/tests/goldens/$1"-*/; do
        [ -d "$d" ] || continue
        m=$(basename "$d")
        case "$tests" in *" $m "*) continue ;; esac
        [ -n "$(ls "$d"*.png 2>/dev/null)" ] && return 0
    done
    [ -n "$(ls "$ROOT/examples/$1/goldens/"*.png 2>/dev/null)" ] && return 0
    [ -d "$ROOT/tests/src" ] && grep -rqE "\"$1[:,] " "$ROOT/tests/src" && return 0
    return 1
}

# An example's web-size record's latest code per emcc, in KB to one decimal, one a line.
recordedKb() {
    awk -F '[:,]' '
        /"emcc":/ { e = $2; gsub(/[ "]/, "", e) }
        /"code":/ { c = $2; gsub(/ /, "", c); last[e] = c }
        END { for (e in last) printf "%.1f\n", last[e] / 1000 }
    ' "$1"
}

tab=$(printf '\t')
while IFS="$tab" read -r kind line f t eg b; do
    [ "$kind" = BUILT ] || continue
    heldBy "$t" || problems="$problems
line $line: test \"$t\" is claimed built, and nothing holds it by that name: no golden tests/goldens/$t/ or $t-<method>/, no examples/$t/goldens/, no case named \"$t: …\""
    case "$b" in
        "with "*)
            ex=${b#with }
            if [ "$ex" != "$eg" ]; then
                problems="$problems
line $line: \"$f\"'s budget waits on $ex, where its example is $eg"
            else
                case "$live" in
                    *" $ex "*) ;;
                    *) problems="$problems
line $line: \"$f\"'s budget waits on $ex, which no live row schedules: measure it" ;;
                esac
            fi
            ;;
        *" KB, the "*"'s")
            kb=${b%% KB*}
            ex=${b#* KB, the }
            ex=${ex%\'s}
            record="$ROOT/examples/$ex/web-size.json"
            if [ ! -f "$record" ]; then
                problems="$problems
line $line: \"$f\" shares $ex's measurement, and examples/$ex/web-size.json does not exist"
            elif ! recordedKb "$record" | grep -qx "$kb"; then
                problems="$problems
line $line: \"$f\" says $kb KB, the $ex's, and its record says $(recordedKb "$record" | tr '\n' ' ' | sed 's/ $//') KB"
            fi
            ;;
        *)
            problems="$problems
line $line: \"$f\"'s budget \"$b\" is neither <n.n> KB, the <example>'s, nor with <example>"
            ;;
    esac
done <<EOF
$built
EOF
problems=$(printf '%s\n' "$problems" | grep .)

if [ -n "$problems" ]; then
    echo "check-features: FAIL —" >&2
    printf '%s\n' "$problems" | sed 's/^/    /' >&2
    exit 1
fi

count() { printf '%s\n' "$rows" | awk -F '\t' -v s="$1" '$1 == "FT" && $5 == s' | grep -c .; }
nf=$(printf '%s\n' "$rows" | grep -c '^FT')
ne=$(printf '%s\n' "$rows" | grep -c '^EX')
na=$(printf '%s\n' "$rows" | awk -F '\t' '$1 == "FT" && $6 == "asked"' | grep -c .)
echo "check-features: OK ($nf features: $(count built) built, $(count partial) partial, $(count planned) planned; $na asked for by"
echo "                    no example yet; $ne examples, each scheduled by a row; every test name unique, and each built"
echo "                    one held by its golden or its named cases)"
