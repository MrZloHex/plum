#!/bin/bash
# Refresh the bootstrap seed from the current source.
#
# Valid only while the CURRENT seed can still compile src/. That is the
# whole invariant: every seed must be able to build its successor. Run
# this BEFORE src/ starts using a language feature the seed lacks.
#
# Typical use, adding a feature F:
#
#   1. implement F in src/, but do not use it yet
#   2. ./refresh-seed.sh          <- the seed now understands F
#   3. start using F in src/
#   4. ./seed-build.sh            <- confirms the seed still suffices
#   5. commit src/ and seed/plc.ll together
set -e
cd "$(dirname "$0")/.."

LLVM_LIBS=$(llvm-config --ldflags --libs core analysis target)
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT

echo "1/5  assembling the current seed"
llc -O0 -relocation-model=pic -filetype=obj seed/plc.ll -o "$T/seed.o"
clang "$T/seed.o" -o "$T/seed" $LLVM_LIBS 2>/dev/null

echo "2/5  compiling src/ with it"
if ! "$T/seed" src/main.pl -o "$T/next.ll" --emit=IR; then
    echo >&2
    echo "The current seed cannot compile src/." >&2
    echo "src/ is already using something the seed does not understand." >&2
    echo "Recover by reverting that use, refreshing, then reapplying it." >&2
    exit 1
fi
llc -O0 -relocation-model=pic -filetype=obj "$T/next.ll" -o "$T/next.o"
clang "$T/next.o" -o "$T/next" $LLVM_LIBS 2>/dev/null

# The old seed and the new compiler need not emit the same IR -- they
# differ whenever codegen changed, which is often the point. What must hold
# is that the new compiler, built by itself, reproduces itself exactly.
echo "3/5  compiling src/ with the result"
"$T/next" src/main.pl -o "$T/next2.ll" --emit=IR
llc -O0 -relocation-model=pic -filetype=obj "$T/next2.ll" -o "$T/next2.o"
clang "$T/next2.o" -o "$T/next2" $LLVM_LIBS 2>/dev/null

echo "4/5  checking the self-built compiler reproduces itself"
"$T/next2" src/main.pl -o "$T/next3.ll" --emit=IR
if ! cmp -s "$T/next2.ll" "$T/next3.ll"; then
    echo "no fixed point -- refusing to adopt this seed" >&2
    diff <(head -c 200000 "$T/next2.ll") <(head -c 200000 "$T/next3.ll") | head -10 >&2
    exit 1
fi

echo "5/5  adopting"
cp "$T/next3.ll" seed/plc.ll
echo
echo "seed refreshed ($(wc -c < seed/plc.ll) bytes)"
echo "commit seed/plc.ll together with the src/ change that needed it"
