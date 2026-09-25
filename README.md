
  	░▒▓███████▓▒░░▒▓█▓▒░     ░▒▓█▓▒░░▒▓█▓▒░▒▓██████████████▓▒░
  	░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░     ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░
  	░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░     ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░
  	░▒▓███████▓▒░░▒▓█▓▒░     ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░
  	░▒▓█▓▒░      ░▒▓█▓▒░     ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░
  	░▒▓█▓▒░      ░▒▓█▓▒░     ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░
  	░▒▓█▓▒░      ░▒▓████████▓▒░▒▓██████▓▒░░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░


  ░▒▓█ _PLUM_█▓▒░

**PLUM** is a low-level, C-ABI-compatible language. `plc`, its compiler, is
written in PLUM and compiles itself.

```plum
!USES <cstdio.pl>

TYPE Node: STRUCT
 | I32   kind
 | @Node next
 \_

I32 main: []
 | @Node n = (malloc)[ SIZE [ Node ] ]
 | n.kind = 1
 | IF [ n.kind == 1 && n.next == 0 ]
 |  | (puts)[ "hello from PLUM" ]
 |  \_
 | RET [ 0 ]
 \_
```

## Build

A machine with LLVM and no `plc` builds one from the checked-in seed:

```sh
make                    # -> bin/plc
```

That is the whole dependency list: `llvm-as`, `clang`, `llvm-config`.
No C compiler is needed for `plc` itself.

```sh
make help               # every target
make test               # 28 programs must compile, link and run
make typecheck          # 11 programs that must be rejected
make bootstrap          # the frozen C compiler -> bin/plc-bootstrap
make selfhost           # stage 1 -> 2 -> 3, and check the fixed point
make seed-verify        # check the seed against the C compiler
```

## Layout

```
src/           plc, written in PLUM: preproc lexer parser meta check codegen
lib/           runtime: string vec map stack arena
extern/        declarations of libc and the LLVM-C API
seed/          the bootstrap seed, as LLVM IR
bootstrap/     the C compiler that produced the first seed; frozen
scripts/       bootstrap, seed refresh and verification
test/          28 programs, plus typecheck/ for what must be rejected
editor/vim/    syntax highlighting
syntax/        plum.ebnf, a grammar sketch (drifted; trust the compiler)
examples/      sample programs, some aspirational
docs/          older notes
```

## Documentation

* **[LANGUAGE.md](LANGUAGE.md)** -- what the language can and cannot express
* **[BOOTSTRAP.md](BOOTSTRAP.md)** -- how the compiler builds itself, and
  the rule for adding a feature without breaking that
