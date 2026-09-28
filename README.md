
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

That is the whole dependency list: `llc`, `clang`, `llvm-config`. `llc`
turns the IR into machine code; `clang` only links it against libc and
LLVM, so no C is compiled for `plc` itself.

```sh
make help               # every target
make test               # 45 programs must print exactly their .out files,
                        #   and the driver must fail properly on bad input
make typecheck          # 72 programs that must be rejected, each for its .err reason
make fuzz               # thousands of mutated programs: plc must never crash
make bootstrap          # the frozen C compiler -> bin/plc-bootstrap
make selfhost           # stage 1 -> 2 -> 3, and check the fixed point
make seed-verify        # check the seed against the C compiler
```

## Using it

```sh
bin/plc hello.pl -o hello.ll            # LLVM IR, the default
bin/plc --emit=OBJ hello.pl -o hello.o  # machine code; --emit=ASM for assembly
clang hello.o -o hello                  # clang only links
bin/plc -O2 ...                         # optimise, -O0 to -O3; -O0 is the default
```

`--target=<triple>` generates code for another machine, with `--cpu=` for a
particular chip and `--data-sections` to give every global a section of its
own. `examples/stm32g071/` runs a PLUM program on a NUCLEO-G071RB board,
startup code included, with no C.

## Editor support

`plc --lsp` is a language server: diagnostics as you type, go to
definition, and hover, for any LSP client. For each change it runs
`plc --emit=INDEX --stdin <file>` on the unsaved text, which prints every
error and every name with its declaration, one per line.

Vim: `editor/vim/install.sh` for the filetype, then, with YouCompleteMe:

```vim
let g:ycm_language_server = [
  \ { 'name': 'plum',
  \   'cmdline': [ '/path/to/plum/bin/plc', '--lsp' ],
  \   'filetypes': [ 'plum' ] } ]
```

`:YcmCompleter GoTo` jumps to a declaration; `:YcmCompleter GetHover` shows
it. Each file is analysed as if it were compiled on its own, so every file
`!USES` what it needs.

## Layout

```
src/           plc, written in PLUM: preproc lexer parser generic meta check codegen,
               and index json lsp for the language server
lib/           runtime: String and Vector<T> (classes), map stack arena
extern/        declarations of libc and the LLVM-C API
seed/          the bootstrap seed, as LLVM IR
bootstrap/     the C compiler that produced the first seed; frozen
scripts/       bootstrap, seed refresh and verification
test/          45 programs, plus typecheck/ for what must be rejected
editor/vim/    syntax highlighting, filetype settings
syntax/        plum.ebnf, a grammar sketch (drifted; trust the compiler)
examples/      sample programs, some aspirational
docs/          older notes
```

## Documentation

* **[LANGUAGE.md](LANGUAGE.md)** -- what the language can and cannot express
* **[BOOTSTRAP.md](BOOTSTRAP.md)** -- how the compiler builds itself, and
  the rule for adding a feature without breaking that
