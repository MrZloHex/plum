#!/bin/bash
# The driver and everything before the parser: exit codes and messages for
# bad command lines, missing files, and malformed source. A build script
# trusts plc's exit code, so every failure here must be non-zero.

cd "$(dirname "$0")"
PLC="${PLC:-../../bin/plc}"
[ -x "$PLC" ] || { echo "no $PLC; build it first" >&2; exit 1; }

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0

# expect <name> <exit code> <text the output must contain> -- plc args...
expect() {
    local name=$1 want_rc=$2 want_text=$3; shift 4
    local out rc
    out=$("$PLC" "$@" 2>&1); rc=$?
    printf '%-20s ' "$name"
    if [ $rc -ne $want_rc ]; then
        echo "*** exit $rc, want $want_rc"; echo "$out" | head -2 | sed 's/^/                     /'
        fail=$((fail+1))
    elif ! grep -qF -- "$want_text" <<<"$out"; then
        echo "*** output lacks: $want_text"; echo "$out" | head -2 | sed 's/^/                     /'
        fail=$((fail+1))
    else
        echo "ok"
        pass=$((pass+1))
    fi
}

src() { printf "$2" > "$TMP/$1"; }

src ok.pl 'I32 main: []\n | RET [ 0 ]\n \\_\n'
src tab.pl 'I32 main: []\n\t| RET [ 0 ]\n \\_\n'
src string.pl 'I32 main: []\n | RET [ "unterminated ]\n \\_\n'
src char.pl 'I32 main: []\n | RET [ 0 ] $\n \\_\n'
src uses_missing.pl '!USES <missing.pl>\nI32 main: []\n | RET [ 0 ]\n \\_\n'
src uses_bare.pl '!USES missing.pl\nI32 main: []\n | RET [ 0 ]\n \\_\n'
src uses_open.pl '!USES <unterminated\nI32 main: []\n | RET [ 0 ]\n \\_\n'
src indent.pl 'I32 main: []\n |  | RET [ 0 ]\n \\_\n'
src empty.pl ''
src noeol.pl 'I32 main: []\n | RET [ 0 ]\n \\_'
src crlf.pl 'I32 main: []\r\n | RET [ 0 ]\r\n \\_\r\n'

expect no-input          1 "no input file"            -- 
expect missing-file      1 "cannot find"         -- "$TMP/nope.pl"
expect o-without-arg     1 "-o needs a file name"      -- -o
expect bad-emit          1 "--emit takes AST or IR"    -- "$TMP/ok.pl" --emit=BOGUS
expect unwritable        1 "cannot write"           -- "$TMP/ok.pl" -o "$TMP/no/such/dir.ll"
expect help              0 "Usage:"                    -- -h
expect emit-ast          0 "1 top-level statements"    -- "$TMP/ok.pl" --emit=AST
expect emit-ir           0 "define i32 @main"          -- "$TMP/ok.pl" --emit=IR
expect tab               33 "a tab; PLUM is indented"      -- "$TMP/tab.pl" -o /dev/null
expect open-string       1 "never closed with"              -- "$TMP/string.pl" -o /dev/null
expect bad-char          1 "is not part of PLUM"         -- "$TMP/char.pl" -o /dev/null
expect uses-missing      1 "cannot open"               -- "$TMP/uses_missing.pl" -o /dev/null
expect uses-no-angle     1 "in angle brackets"              -- "$TMP/uses_bare.pl" -o /dev/null
expect uses-unclosed     1 'never closed with `>`'               -- "$TMP/uses_open.pl" -o /dev/null
expect bad-indent        1 "outside any block"        -- "$TMP/indent.pl" -o /dev/null
expect empty-file        0 ""                          -- "$TMP/empty.pl" -o /dev/null
expect no-final-newline  0 ""                          -- "$TMP/noeol.pl" -o /dev/null
expect crlf              0 ""                          -- "$TMP/crlf.pl" -o /dev/null

# Diagnostics: on stderr alone, located in the file the user wrote -- even
# after an include -- with the line and a caret under the column.
src inc.pl 'I32 fine = 1\n'
src located.pl '!USES <inc.pl>\nI32 main: []\n | I32 x = 1\n | RET [ y ]\n \\_\n'

printf '%-20s ' "stderr-only"
if [ -z "$("$PLC" "$TMP/located.pl" -o /dev/null 2>/dev/null)" ]; then
    echo ok; pass=$((pass+1))
else
    echo "*** a diagnostic went to stdout"; fail=$((fail+1))
fi

want=$(printf '%s\n' \
    "error: unknown identifier \`y\`" \
    " --> $TMP/located.pl:4:10" \
    "  |" \
    "4 |  | RET [ y ]" \
    "  |          ^" \
    "1 error")
got=$("$PLC" "$TMP/located.pl" -o /dev/null 2>&1)
printf '%-20s ' "diagnostic-format"
if [ "$got" = "$want" ]; then
    echo ok; pass=$((pass+1))
else
    echo "*** got:"; echo "$got" | sed 's/^/                     /'; fail=$((fail+1))
fi

echo
echo "passed $pass, failed $fail"
[ $fail -gt 0 ] && exit 1
exit 0
