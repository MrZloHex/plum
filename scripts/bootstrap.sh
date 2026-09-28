#!/bin/bash
# Full bootstrap: C plc -> PLUM plc -> itself -> fixed point.
#
# Stage 1 is the only step that needs the C compiler. From stage 2 on it is
# PLUM compiling PLUM; the run fails if the fixed point is ever lost.
set -e
cd "$(dirname "$0")/.."

LLVM_LIBS=$(llvm-config --ldflags --libs core analysis target)
link() { llc -O0 -relocation-model=pic -filetype=obj "$1" -o "${1%.ll}.o"; clang "${1%.ll}.o" -o "$2" $LLVM_LIBS 2>/dev/null; }

echo "stage 1: C plc compiles the PLUM compiler"
bin/plc-bootstrap src/main.pl -o stage1.ll --emit=IR 2>/dev/null
link stage1.ll plc-plum

echo "stage 2: the PLUM compiler compiles itself"
./plc-plum src/main.pl -o stage2.ll --emit=IR
link stage2.ll plc-plum2

echo "stage 3: the self-compiled compiler compiles itself again"
./plc-plum2 src/main.pl -o stage3.ll --emit=IR

if cmp -s stage2.ll stage3.ll; then
    echo "FIXED POINT: stage2.ll == stage3.ll ($(wc -c < stage2.ll) bytes)"
else
    echo "NOT a fixed point -- stage2 and stage3 differ"; exit 1
fi
