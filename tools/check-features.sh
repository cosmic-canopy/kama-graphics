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
#   5. Its test is a kebab-case name, unique, and once a method is built, `tests/` has it.
#   6. Its budget is `—` while planned, and measured (anything else) once a method is built.
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
        if (st == "planned" && b != "—") print "line " $2 ": \"" f "\" is planned, so its budget is — until a measurement sets it"
        if (st != "planned" && (b == "—" || b == "")) print "line " $2 ": \"" f "\" has a built method, so its budget is the measured one"
        if (st != "planned") print "BUILT\t" t
    }
    END {
        if (nex == 0) print "no examples table"
        if (nft == 0) print "no feature rows"
        for (e in want) if (!(e in ex)) print "line" want[e] ": example \"" e "\" is not declared in the examples table"
        for (e in ex) if (!(e in used)) print "example \"" e "\" is declared, and no feature row needs it"
    }
')

built=$(printf '%s\n' "$problems" | awk -F '\t' '$1 == "BUILT" { print $2 }')
problems=$(printf '%s\n' "$problems" | grep -v '^BUILT' | grep .)

for t in $built; do
    [ -d "$ROOT/tests" ] && grep -rqw -- "$t" "$ROOT/tests" || problems="$problems
test \"$t\" is claimed built, and tests/ does not have it"
done
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
echo "                    no example yet; $ne examples, each scheduled by a row; every test name unique)"
