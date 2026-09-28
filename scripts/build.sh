#!/bin/bash
# Build the PLUM compiler with an existing plc (stage 1 of the bootstrap).
set -e
cd "$(dirname "$0")/.."

PLC="${PLC:-bin/plc-bootstrap}"
OUT="${OUT:-plc-plum}"

"$PLC" src/main.pl -o "$OUT.ll" --emit=IR
llc -O0 -relocation-model=pic -filetype=obj "$OUT.ll" -o "$OUT.o"
clang "$OUT.o" -o "$OUT" $(llvm-config --ldflags --libs core analysis target) 2>&1 \
    | grep -v "overriding the module target triple" || true

echo "built $OUT"
