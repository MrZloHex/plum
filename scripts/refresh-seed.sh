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

echo "1/4  assembling the current seed"
llvm-as seed/plc.ll -o "$T/seed.bc"
clang "$T/seed.bc" -o "$T/seed" $LLVM_LIBS 2>/dev/null

echo "2/4  compiling src/ with it"
if ! "$T/seed" src/main.pl -o "$T/next.ll" --emit=IR; then
    echo >&2
    echo "The current seed cannot compile src/." >&2
    echo "src/ is already using something the seed does not understand." >&2
    echo "Recover by reverting that use, refreshing, then reapplying it." >&2
    exit 1
fi
llvm-as "$T/next.ll" -o "$T/next.bc"
clang "$T/next.bc" -o "$T/next" $LLVM_LIBS 2>/dev/null

echo "3/4  checking the result reaches a fixed point"
"$T/next" src/main.pl -o "$T/next2.ll" --emit=IR
if ! cmp -s "$T/next.ll" "$T/next2.ll"; then
    echo "no fixed point -- refusing to adopt this seed" >&2
    exit 1
fi

echo "4/4  adopting"
cp "$T/next2.ll" seed/plc.ll
echo
echo "seed refreshed ($(wc -c < seed/plc.ll) bytes)"
echo "commit seed/plc.ll together with the src/ change that needed it"
