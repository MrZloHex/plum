#!/bin/bash
# Build and run every test, and compare what it prints with <name>/<name>.out.
#
#   ./run.sh              run all tests
#   ./run.sh -u [names]   rewrite the expected output from what runs now --
#                         read the diff before committing it
#   ./run.sh names...     run only these
#
# An .out file holds the program's stdout and stderr, then `[exit N]`.
# Timestamps are masked, so trace output compares across runs.

UPDATE=false
[[ "$1" == "-u" ]] && { UPDATE=true; shift; }

TESTS=(
    simplest c_call elif if_stmt logic loops
    bitwise casts globals byvalue selfref compilerish
    string containers llvm trace preproc lexer
    ast parser meta printf aryph_logic cli_args
    arrays struct include std
    generics vector floats indexing
    semantics fnptr
    generics_edge core order ptrmath numbers returns arena
    fnptr_edge include_once vectors anonymous req qualifiers req_impl req_method layout
    method_ptr req_contract generic_fn
    small_syntax for_loop switch postlude va_forward initialiser
)
[[ $# -gt 0 ]] && TESTS=("$@")

normalise() {
    sed -E 's/\[[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}\]/[TIME]/'
}

pass=0; fail=0; failed=()

for t in "${TESTS[@]}"; do
    printf '%-12s ' "$t"

    out=$(./build.sh -t "$t" 2>&1)
    if [[ $? -ne 0 ]] || echo "$out" | grep -qiE "error|FATAL|Segmentation"; then
        echo "BUILD FAIL"
        echo "$out" | grep -iE "error|FATAL|^[0-9]+:[0-9]+:" | head -3 | sed 's/^/             /'
        fail=$((fail+1)); failed+=("$t"); continue
    fi

    got=$( cd "$t" && timeout 10 "./$t" 2>&1; echo "[exit $?]" )
    got=$(echo "$got" | normalise)
    want_file="$t/$t.out"

    if $UPDATE; then
        echo "$got" > "$want_file"
        echo "updated"
        pass=$((pass+1)); continue
    fi

    if [[ ! -f "$want_file" ]]; then
        echo "NO EXPECTED OUTPUT (./run.sh -u $t, then check it)"
        fail=$((fail+1)); failed+=("$t"); continue
    fi

    if [[ "$got" != "$(cat "$want_file")" ]]; then
        echo "WRONG OUTPUT"
        diff <(cat "$want_file") <(echo "$got") | head -10 | sed 's/^/             /'
        fail=$((fail+1)); failed+=("$t"); continue
    fi

    echo "ok"
    pass=$((pass+1))
done

echo
echo "passed $pass, failed $fail"
[[ $fail -gt 0 ]] && { echo "failing: ${failed[*]}"; exit 1; }
exit 0
