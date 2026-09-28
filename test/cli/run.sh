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
expect bad-emit          1 "--emit takes AST, IR, ASM, OBJ or INDEX" -- "$TMP/ok.pl" --emit=BOGUS
expect bad-opt           1 "the optimisation levels are"   -- "$TMP/ok.pl" -O4
expect unwritable        1 "cannot write"           -- "$TMP/ok.pl" -o "$TMP/no/such/dir.ll"
expect help              0 "Usage:"                    -- -h
expect emit-ast          0 "FN_DEF I32 main: [ ]"      -- "$TMP/ok.pl" --emit=AST
expect emit-ast-tree     0 "    INT 0"                 -- "$TMP/ok.pl" --emit=AST
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

# Machine code straight from plc: an object clang only has to link, the
# same as assembly, the optimiser, and a global per section.
src sq.pl 'I32 g = 7\nI32 z\nI32 sq: [ I32 x ]\n | I32 r = x * x\n | RET [ r ]\n \\_\nI32 main: []\n | RET [ (sq)[ g ] + z ]\n \\_\n'
printf '%-20s ' "emit-obj"
if "$PLC" --emit=OBJ "$TMP/sq.pl" -o "$TMP/sq.o" && clang "$TMP/sq.o" -o "$TMP/sq" 2>/dev/null; then
    "$TMP/sq"; rc=$?
    if [ $rc -eq 49 ]; then echo ok; pass=$((pass+1)); else echo "*** ran, exit $rc, want 49"; fail=$((fail+1)); fi
else
    echo "*** no object, or it did not link"; fail=$((fail+1))
fi
expect emit-asm-arm      0 "muls"                      -- "$TMP/sq.pl" --emit=ASM -O2 --target=thumbv6m-unknown-none-eabi --cpu=cortex-m0plus -o -
printf '%-20s ' "opt-o2"
got=$("$PLC" -O2 "$TMP/sq.pl" -o - | sed -n '/define.*@sq/,/^}/p')
if grep -q 'mul i32' <<<"$got" && ! grep -q alloca <<<"$got"; then
    echo ok; pass=$((pass+1))
else
    echo "*** -O2 left sq unoptimised:"; echo "$got" | sed 's/^/                     /'; fail=$((fail+1))
fi
printf '%-20s ' "data-sections"
"$PLC" --emit=OBJ --data-sections --target=thumbv6m-unknown-none-eabi "$TMP/sq.pl" -o "$TMP/arm.o"
secs=$(llvm-readelf -S "$TMP/arm.o" 2>/dev/null)
if grep -q '\.data\.g ' <<<"$secs" && grep -q '\.bss\.z ' <<<"$secs"; then
    echo ok; pass=$((pass+1))
else
    echo "*** no .data.g and .bss.z sections"; fail=$((fail+1))
fi

# VOLATILE survives the optimiser: at -O2, two stores to the same register
# stay two stores, and a CONST global is constant.
src mmio.pl 'CONST @VOLATILE U32 REG = 0x40000000 AS @VOLATILE U32\nCONST I32 K = 3\nI32 main: []\n | ?REG = 1\n | ?REG = 2\n | RET [ K ]\n \\_\n'
printf '%-20s ' "volatile-o2"
ir=$("$PLC" -O2 "$TMP/mmio.pl" -o -)
if [ "$(grep -c 'store volatile' <<<"$ir")" -eq 2 ] && grep -q '^@K = .*constant' <<<"$ir"; then
    echo ok; pass=$((pass+1))
else
    echo "*** want 2 volatile stores and a constant K:"; echo "$ir" | grep -E 'store|@K' | sed 's/^/                     /'; fail=$((fail+1))
fi

# --emit=INDEX, what --lsp runs: diagnostics as E lines and names as R
# lines, all on stdout, tab-separated; with --stdin the text comes from
# stdin, and the file named need not exist.
T=$'\t'
src idx.pl '!USES <inc.pl>\nI32 main: []\n | RET [ fine ]\n \\_\n'

expect index-error       1 "E${T}$TMP/located.pl${T}4${T}10${T}unknown identifier \`y\`" -- "$TMP/located.pl" --emit=INDEX
expect index-use         0 "R${T}$TMP/idx.pl${T}3${T}10${T}$TMP/inc.pl${T}1${T}5${T}I32 fine" -- "$TMP/idx.pl" --emit=INDEX
expect index-decl        0 "R${T}$TMP/idx.pl${T}2${T}5${T}$TMP/idx.pl${T}2${T}5${T}I32 main: [ ]" -- "$TMP/idx.pl" --emit=INDEX

printf '%-20s ' "index-stdin"
got=$(printf 'I32 main: []\n | RET [ z ]\n \\_\n' | "$PLC" --emit=INDEX --stdin "$TMP/unsaved.pl" 2>&1)
if grep -qxF "E${T}$TMP/unsaved.pl${T}2${T}10${T}unknown identifier \`z\`" <<<"$got"; then
    echo ok; pass=$((pass+1))
else
    echo "*** got:"; echo "$got" | sed 's/^/                     /'; fail=$((fail+1))
fi

# --lsp: one scripted session. The file uses `fine` from inc.pl and an
# unknown `h`; the server must report `h`, and resolve and describe `fine`.
# The URI is spelled file:/path, as YouCompleteMe does, so USES must still
# resolve against the right directory.
frame() { printf 'Content-Length: %d\r\n\r\n%s' "$(LC_ALL=C; echo ${#1})" "$1"; }
U="file:$TMP/lsp.pl"
session() {
    frame '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"capabilities":{}}}'
    frame '{"jsonrpc":"2.0","method":"initialized","params":{}}'
    frame '{"jsonrpc":"2.0","method":"textDocument/didOpen","params":{"textDocument":{"uri":"'"$U"'","languageId":"plum","version":1,"text":"!USES <inc.pl>\nI32 main: []\n | RET [ fine + h ]\n \\_\n"}}}'
    frame '{"jsonrpc":"2.0","id":2,"method":"textDocument/definition","params":{"textDocument":{"uri":"'"$U"'"},"position":{"line":2,"character":9}}}'
    frame '{"jsonrpc":"2.0","id":"h","method":"textDocument/hover","params":{"textDocument":{"uri":"'"$U"'"},"position":{"line":2,"character":9}}}'
    frame '{"jsonrpc":"2.0","id":3,"method":"shutdown"}'
    frame '{"jsonrpc":"2.0","method":"exit"}'
}
out=$(session | "$PLC" --lsp); rc=$?
lsp_check() {
    printf '%-20s ' "$1"
    if [ $rc -eq 0 ] && grep -qF -- "$2" <<<"$out"; then
        echo ok; pass=$((pass+1))
    else
        echo "*** exit $rc, output lacks: $2"; fail=$((fail+1))
    fi
}
lsp_check lsp-diagnostic '"diagnostics":[{"range":{"start":{"line":2,"character":16},"end":{"line":2,"character":17}},"message":"unknown identifier `h`"'
lsp_check lsp-definition '"id":2,"result":{"uri":"file://'"$TMP"'/inc.pl","range":{"start":{"line":0,"character":4},"end":{"line":0,"character":8}}}'
lsp_check lsp-hover      '"id":"h","result":{"contents":{"kind":"plaintext","value":"I32 fine"}'
lsp_check lsp-shutdown   '"id":3,"result":null'

echo
echo "passed $pass, failed $fail"
[ $fail -gt 0 ] && exit 1
exit 0
