#!/bin/bash
# Programs that MUST be rejected by the type checker.
#
# run.sh next door checks that valid programs compile; this checks that
# invalid ones do not. Each file here is a bug that was once accepted
# silently and produced wrong code or invalid IR.

cd "$(dirname "$0")"
PLC="${PLC:-../../bin/plc}"

[ -x "$PLC" ] || { echo "no $PLC; build it first" >&2; exit 1; }

# With -u, record each program's first diagnostic -- message and location --
# in <name>.err; without,
# the diagnostic must match it, so a program rejected for the wrong reason
# fails too.
UPDATE=false
[ "$1" = "-u" ] && UPDATE=true

pass=0; fail=0
for f in *.pl; do
    name="${f%.pl}"
    printf '%-16s ' "$name"
    out=$("$PLC" "$f" -o /dev/null --emit=IR 2>&1)
    if [ $? -ne 0 ]; then
        # the first diagnostic: `error: ...` and the ` --> file:line:col` under it
        first=$(echo "$out" | head -2)
        if $UPDATE; then
            echo "$first" > "$name.err"
        fi
        if [ ! -f "$name.err" ]; then
            echo "*** no $name.err; run with -u and check it ***"
            fail=$((fail+1))
        elif [ "$first" != "$(cat "$name.err")" ]; then
            echo "*** rejected for the wrong reason ***"
            echo "$(cat "$name.err")" | sed 's/^/                 want: /'
            echo "$first" | sed 's/^/                 got:  /'
            fail=$((fail+1))
        else
            echo "rejected: $(echo "$first" | head -1)"
            pass=$((pass+1))
        fi
    else
        echo "*** ACCEPTED -- the checker missed this ***"
        fail=$((fail+1))
    fi
done

echo
echo "rejected $pass, missed $fail"
[ $fail -gt 0 ] && exit 1
exit 0
