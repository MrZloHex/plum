#!/bin/bash
# Build and run every test. `-v` also prints each program's output.
#
# A test passes when it compiles, links and runs without crashing; there are
# no expected-output files, so `-v` is how you check behaviour by eye.

VERBOSE=false
[[ "$1" == "-v" ]] && VERBOSE=true

TESTS=(
    simplest c_call elif if_stmt logic loops
    bitwise casts globals byvalue selfref compilerish
    string containers llvm trace preproc lexer
    ast parser meta printf aryph_logic cli_args
    arrays struct include std
)

pass=0; fail=0; failed=()

for t in "${TESTS[@]}"; do
    printf '%-12s ' "$t"

    out=$(./build.sh -t "$t" 2>&1)
    if echo "$out" | grep -qiE "error|FATAL|Segmentation"; then
        echo "BUILD FAIL"
        echo "$out" | grep -iE "error|FATAL" | head -2 | sed 's/^/             /'
        fail=$((fail+1)); failed+=("$t"); continue
    fi

    run=$( cd "$t" && timeout 10 "./$t" 2>&1 ); rc=$?
    if [[ $rc -ge 125 ]]; then
        echo "RUN FAIL ($rc)"
        fail=$((fail+1)); failed+=("$t"); continue
    fi

    echo "ok (exit $rc)"
    $VERBOSE && echo "$run" | sed 's/^/             /'
    pass=$((pass+1))
done

echo
echo "passed $pass, failed $fail"
[[ $fail -gt 0 ]] && { echo "failing: ${failed[*]}"; exit 1; }
exit 0
