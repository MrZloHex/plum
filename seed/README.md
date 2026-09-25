# Bootstrap seed

`plc.ll` is the PLUM compiler, in LLVM IR, emitted by a known-good PLUM
compiler. It exists so a machine with no `plc` can still build one.

    llvm-as seed/plc.ll -o plc.bc
    clang   plc.bc -o plc-plum $(llvm-config --ldflags --libs core analysis target)

`../seed-build.sh` does exactly that, then rebuilds the compiler from
`src/` with the result and checks the two agree.

## What it pins

The seed carries a `target triple` and `datalayout`, so it is
**x86_64 linux**. On another target, regenerate it there from the C
compiler in `../src` (see below) rather than reusing this file. It also
wants an LLVM whose `llvm-as` accepts IR of the version that produced it.

## Refreshing it

The seed only has to be recent enough to compile the current `src/`.
Refresh it when that stops being true, or after any language change the
old seed cannot parse:

    ./bootstrap.sh              # reaches a fixed point
    cp stage2.ll seed/plc.ll    # adopt it

## Trust

While `../../bootstrap/src` (the C compiler) is still around, the seed is verifiable:
it should be byte-identical to what a C-built `plc-plum` emits for
`src/main.pl`. `../seed-verify.sh` checks that. Once the C compiler is
gone the seed becomes the anchor, and can only be checked against itself
-- which is the usual bootstrapping trade, and the reason to keep the C
compiler in git history even if it leaves the build.
