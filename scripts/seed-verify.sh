#!/bin/bash
# While the C compiler still exists, confirm the seed is what it claims:
# the IR a C-built PLUM compiler emits for src/main.pl.
set -e
cd "$(dirname "$0")/.."

[ -x bin/plc-bootstrap ] || { echo "bin/plc-bootstrap not built; nothing to verify against" >&2; exit 1; }

LLVM_LIBS=$(llvm-config --ldflags --libs core analysis target)
bin/plc-bootstrap src/main.pl -o /tmp/plum-v1.ll --emit=IR 2>/dev/null
llc -O0 -relocation-model=pic -filetype=obj /tmp/plum-v1.ll -o /tmp/plum-v1.o
clang /tmp/plum-v1.o -o /tmp/plum-v1 $LLVM_LIBS 2>/dev/null
/tmp/plum-v1 src/main.pl -o /tmp/plum-v2.ll --emit=IR

if cmp -s /tmp/plum-v2.ll seed/plc.ll; then
    echo "seed VERIFIED against the C compiler"
else
    echo "seed does NOT match what the C compiler produces" >&2
    diff <(head -20 /tmp/plum-v2.ll) <(head -20 seed/plc.ll) | head -10
    exit 1
fi
