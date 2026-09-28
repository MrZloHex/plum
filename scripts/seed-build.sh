#!/bin/bash
# Build plc from the checked-in seed, with no pre-existing plc and no C
# compiler for the compiler itself. Then rebuild from source with the
# result and check the two agree.
set -e
cd "$(dirname "$0")/.."

LLVM_LIBS=$(llvm-config --ldflags --libs core analysis target)

echo "seed -> plc-seed"
llc -O0 -relocation-model=pic -filetype=obj seed/plc.ll -o seed.o
clang seed.o -o plc-seed $LLVM_LIBS 2>/dev/null

echo "plc-seed compiles src/ -> plc-plum"
./plc-seed src/main.pl -o fromseed.ll --emit=IR
llc -O0 -relocation-model=pic -filetype=obj fromseed.ll -o fromseed.o
clang fromseed.o -o plc-plum $LLVM_LIBS 2>/dev/null

echo "plc-plum compiles src/ again"
./plc-plum src/main.pl -o fromseed2.ll --emit=IR

if cmp -s fromseed.ll fromseed2.ll; then
    echo "FIXED POINT reached from the seed ($(wc -c < fromseed.ll) bytes)"
    echo "built ./plc-plum"
else
    echo "the seed cannot reproduce a fixed point -- refresh it" >&2
    exit 1
fi
