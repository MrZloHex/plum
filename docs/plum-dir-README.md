# plc, written in PLUM

The self-hosting compiler. `../bootstrap/src` is the C compiler that bootstraps
this one; from stage 2 onward PLUM compiles PLUM.

    ./bootstrap.sh      stage 1 -> 2 -> 3, and check the fixed point
    ./build.sh          just stage 1, producing ./plc-plum

## Layout

    src/        the compiler, one file per stage
                main preproc token lexer ast parser meta codegen trace
    lib/        the PLUM runtime
                string vec map stack arena
    extern/     declarations of things implemented elsewhere
                stdio stdlib string ctype time unistd llvm

`extern/` is only declarations -- libc and the LLVM-C API, reached through
opaque `@ABYSS` handles. That is what lets the backend drive LLVM without a
binding layer.

## Where this differs from the C compiler

Three places, each noted at the top of the file that does it:

* `src/trace.pl` takes an already-formatted message. PLUM can call a
  variadic function but cannot consume varargs, so callers run `snprintf`
  themselves. The C version hands a `va_list` to `vsnprintf`.
* `lib/map.pl` fixes the key type to `@C1`. `inc/dynmap.h` takes the hash
  and equality as macro parameters; both live instantiations use string
  keys, which is what avoids needing function pointers.
* `src/meta.pl` repairs bugs rather than reproducing them -- `src/meta.c`
  has no `NT_COND` or `NT_RET` case, so conditionals and return expressions
  are never walked, and its `NT_IF` case reads the wrong union member.

`--emit=AST` is not equivalent either: the C driver prints a full tree,
this one prints a statement count. The AST *types* are ported; `ast_dump`
is not.
