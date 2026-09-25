# Bootstrapping plc

`plc` is written in PLUM. Building it therefore needs a `plc` — which a new
machine does not have. This is how that circle is broken.

The answer is a **seed**: `seed/plc.ll`, the compiler in LLVM IR,
checked into the repository. A machine with LLVM and nothing else can
assemble the seed into a working compiler, then use it to build the real
one from source.

---

## The three paths

### A new user, no `plc` anywhere

```sh
make
```

Assembles `seed/plc.ll`, uses the result to compile `src/`, then compiles
`src/` a second time with *that* and checks the two agree. Leaves
`./plc-plum`. Needs `llvm-as`, `clang` and `llvm-config` — no C compiler
for the compiler itself, and no pre-existing `plc`.

### A developer with the C compiler

```sh
make && make selfhost
```

Stage 1 builds the PLUM compiler with the C one, stage 2 has it compile
itself, stage 3 does it once more, and the run fails unless stage 2 and
stage 3 are byte-identical.

### Checking the seed is honest

```sh
make seed-verify
```

Builds a PLUM compiler with the C compiler, has it emit IR for `src/main.pl`,
and compares that against `seed/plc.ll`. They must match exactly.

---

## What the seed pins

**A target.** The seed carries `target triple` and `datalayout`, so it is
x86_64 Linux. On another architecture, do not reuse it — regenerate it
there from the C compiler.

**Roughly an LLVM version.** `llvm-as` has to accept IR of the vintage that
produced it. The current seed came from LLVM 21.

**Nothing else.** It is 934 KB of text, 127 KB compressed, and it is
readable — you can open it and see what you are about to run.

---

## Refreshing it

The seed only has to be recent enough to compile the current `src/`. It
does not track every change. Refresh it when that stops being true — after
a language change the old seed cannot parse, or a new construct `src/`
starts using:

```sh
make selfhost     # confirm a fixed point
cp stage2.ll seed/plc.ll      # adopt it
make               # confirm the new seed works from cold
```

Commit `seed/plc.ll` alongside the source change that required it, so the
pair stays consistent in history.

---

## Adding a language feature

The moment `src/` uses a feature the seed does not know, the seed can no
longer build the compiler, and the bootstrap is broken. The C compiler
breaks first, and permanently.

The fix is an ordering rule, not a release cadence. The seed lives in this
repository, so it can be advanced in the same commit:

    1. implement the feature in src/ -- but do not use it there yet
    2. make seed-refresh            the seed now understands it
    3. start using it in src/
    4. make              confirms the seed still suffices
    5. commit src/ and seed/plc.ll together

Step 2 is the one that matters. A seed must always be able to build its
successor; refreshing before first use is what keeps that true.

`refresh-seed.sh` enforces it. It builds with the *current* seed, and
refuses to adopt a new one unless that succeeds and reaches a fixed point.
If you have already used the feature too early it says so:

    The current seed cannot compile src/.
    src/ is already using something the seed does not understand.
    Recover by reverting that use, refreshing, then reapplying it.

Which is exactly the recovery: revert the use, refresh, reapply.

### If the chain is already broken

Nothing is lost -- the seed is in git history. Check out the last commit
whose seed builds, refresh forward from there one step at a time, or in
the worst case rebuild from `../bootstrap/src` while the C compiler still parses
enough of the language.

This is also why `git` history matters more than usual here. A seed is
only ever as recoverable as the commit that produced it.

### What the C compiler can and cannot survive

It is frozen, so **every** feature added from now on puts it further
behind. It will stop being able to compile `src/` at the first one, and
that is expected -- its job was to produce the first seed.

`seed-verify.sh` stops working at that same moment, because it derives the
seed through the C compiler. Before taking that step, it is worth tagging
the last commit where `seed-verify.sh` passes: that tag is the last point
at which the seed was independently verifiable from C source.

## What to do with the C compiler

**Keep it in git; take it out of the build.** Two reasons.

It is the only *independent* implementation. Right now both compilers emit
byte-identical IR for all 28 tests, and that agreement is the strongest
correctness evidence the project has. Delete the C compiler and the seed
can only ever be checked against itself.

It is also the way back. If the seed is ever lost, corrupted, or stranded
on an LLVM version that no longer exists, `bootstrap/src/*.c` regenerates it from
nothing but a C toolchain.

What that means concretely: stop developing it, stop mirroring language
changes into it, and let `src/` drift into a historical artifact that still
builds. When it eventually stops being able to compile current PLUM
sources, that is fine — its job was only ever to produce the first seed.

---

## The trust question

A checked-in binary artifact is a thing you have to trust. Worth being
plain about the limits.

While the C compiler exists, the seed is **verifiable**: `seed-verify.sh`
derives it independently from C source you can read. That is real
assurance.

Once the C compiler is gone, it is not. A seed can reproduce itself
faithfully while carrying something the source does not describe — Ken
Thompson's *Reflections on Trusting Trust*. No amount of re-running
`seed-build.sh` detects that, because the seed compiles the compiler that
checks it.

This is the ordinary bootstrapping trade, and every self-hosted language
makes it. Two things make it cheaper here:

* The seed is **text**, not a binary. It is IR you can read, diff between
  refreshes, and search.
* The C compiler stays in history, so an independent re-derivation is
  always one `git checkout` away.

---

## Files

```
seed/plc.ll        the seed: the compiler, as LLVM IR
seed/README.md     how it was made, how to refresh it
make (or scripts/seed-build.sh)      build from the seed, no plc needed
scripts/refresh-seed.sh    advance the seed, safely
scripts/seed-verify.sh     check the seed against the C compiler
scripts/bootstrap.sh       stage 1 -> 2 -> 3 with the C compiler
scripts/build.sh           stage 1 only
```

`.gitignore` keeps `seed/plc.ll` and ignores every other `.ll`, `.bc` and
binary under `src/`.
