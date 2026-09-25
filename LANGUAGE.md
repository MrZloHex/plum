# PLUM — the language

What the compiler accepts today, what it does not, and what could come next.
Everything here was checked against `bootstrap/src/` and `src/`, not against the
grammar sketch in `syntax/plum.ebnf`, which has drifted.

---

## Types

| Spelling | Meaning |
|---|---|
| `ABYSS` | void |
| `B1` | boolean (`i1`) |
| `C1` | character (`i8`) |
| `U8` `U16` `U32` `U64` `USIZE` | unsigned integers |
| `I8` `I16` `I32` `I64` `ISIZE` | signed integers |
| `F32` `F64` | floats — storable and passable; arithmetic on them is **rejected by the type checker**, because the backend has no float opcodes |
| `@T` | pointer, to any depth: `@C1`, `@@C1`, `@@MapEntry` |

`C2` and `C4` appear in `syntax/plum.ebnf` and in the vim syntax file, but
the compiler rejects them. Only `C1` exists.

### User-defined types

```plum
TYPE Point: STRUCT
 | I32 x
 | I32 y
 \_

TYPE Payload: UNION
 | I32 num
 | @C1 text
 \_

TYPE Kind: ENUM
 | K_NUM
 | K_ADD
 \_

TYPE MyInt: @I32          ; alias
```

Structs may reference one another and themselves, so `@Node next` inside
`TYPE Node` works. A union overlays every member at one address. Enum
constants are `I32`, numbered from zero.

---

## Declarations

```plum
I32 puts: [ @C1 str ]                 ; declaration only = extern C function
I32 printf: [ @C1 fmt | ... ]         ; varargs
I32 counter = 0                       ; global, constant initialiser only

I32 add: [ I32 a | I32 b ]            ; declaration + block = definition
 | RET [ a + b ]
 \_
```

Structs pass and return **by value**. Recursion works. Everything lives at
the top level — no nested functions, no visibility modifiers, no modules.

---

## Statements

```plum
 | I32 n = 0                     declaration, initialiser optional
 | n = n + 1                     assignment
 | n += 1                        also -=  *=  /=  %=
 |
 | IF [ c ]
 |  | ...
 | ELIF [ c ]
 |  | ...
 | ELSE
 |  | ...
 |  \_
 |
 | LOOP                          infinite; leave with BREAK
 |  | ...
 |  \_
 |
 | WHILE [ c ]
 |  | ...
 |  \_
 |
 | BREAK
 | CONTINUE
 | RET [ expr ]                  also  RET []  and bare  RET
```

Blocks nest as a run of `|`, and close with `\_`. The depth of that run is
the block's nesting level — which is why the parser is hand-written; it is
not expressible in an LR grammar.

---

## Expressions

**Literals** — `42`, `0xFF`, `0b1010`, `1_000`, `'a'`, `'\n'`, `'\x1b'`,
`"text\n"`, `TRUE`, `FALSE`

| Group | Operators |
|---|---|
| Arithmetic | `+` `-` `*` `/` `%` — signed or unsigned per operand type |
| Bitwise | `&` `\|` `^` `~` `<<` `>>` |
| Comparison | `==` `!=` `<` `<=` `>` `>=` |
| Logical | `&&` `\|\|` `!` — genuinely short-circuiting |
| Pointers | `?p` dereference, `@x` address-of, `p + n` scaled by element size |
| Members | `s.field`, auto-dereferencing through pointers |
| Calls | `(name)[ arg \| arg ]` |
| Casts | `expr AS T` |
| Size | `SIZE [ T ]` |

Member chains go as deep as needed, through pointers and unions alike:
`n.as.bin_op.left.as.literal.as.int_lit`.

Casts are deliberately more permissive than implicit conversion: int to
pointer, pointer to pointer, width changes, int to float. That is what
makes a `malloc` result usable as a typed pointer.

### Precedence, tightest first

```
prefix  ? @ - ! ~
.
AS
* / %
+ -
<< >>
< <= > >=
== !=
&
^
&&
||
|
=
```

Two consequences worth memorising:

* **Prefix binds tighter than `.`**, the opposite of C. `@s.f` groups as
  `(@s).f`, so a field's address is written `@(s.f)`. Dereference works out
  in your favour: `?p.f` is `(?p).f`, which is C's `p->f`.
* **Inside an argument list a bare `|` separates arguments.** A bitwise-or
  there needs parentheses: `(f)[ (a | b) ]`. Everywhere else — initialisers,
  `IF`, `RET`, `WHILE` — `|` is the operator.

---

## Around the language

**Comments** start with `;` and run to end of line.

**`!USES <path>`** includes a file textually, before lexing. Paths resolve
relative to the including file, nesting is capped at 32, and comments and
string literals are skipped so a file can mention the directive without
triggering it.

**C interop** needs no binding layer. Declare the function and call it.
Opaque handles travel as `@ABYSS`, which is how the compiler's own backend
drives the entire LLVM-C API.

---

## The type checker

`src/check.pl` runs between `meta` and `codegen`. It only ever
rejects; it never changes what is emitted, so a program that passes
compiles exactly as it did before the checker existed. The C and PLUM
compilers still emit byte-identical IR for every valid program.

It catches, with a line and column:

* assigning or initialising across incompatible types, aggregates in
  particular
* `.` applied to something with no fields, and unknown field names
* dereferencing a non-pointer
* unknown identifiers
* wrong argument count and wrong argument types, respecting varargs
* returning a value from an `ABYSS` function, or the wrong type from
  any other, or nothing from a non-void one
* redeclaring a name in the same scope
* arithmetic or comparison on a struct
* float arithmetic, which the backend cannot emit

It deliberately does *not* flag mixing signed and unsigned, or narrowing
an integer, since PLUM's implicit coercion already defines those.

`test/typecheck/` holds one program per rejection, each a bug that was
once accepted silently.

## What PLUM cannot express

| Missing | Workaround |
|---|---|
| Arrays — no `I32 a[8]`, no `a[i]` | `malloc` and `?(p + i)` |
| Float arithmetic | none; the type checker rejects it rather than letting it reach LLVM |
| `switch` | `ELIF` chains |
| Ternary `?:` | `IF` |
| `for` | `WHILE` |
| `++` / `--` | `+= 1` |
| Function pointers | none |
| `va_arg` (consuming varargs) | none — callers format first, as `src/trace.pl` does |
| Generics, interfaces, methods | none |
| Modules, namespaces | none |
| Closures, exceptions | none |


Calling a variadic function works; only *consuming* varargs is absent.

---

## What it is good for

The shape PLUM fits is a systems program built from tagged unions and
explicit memory, calling out to C for whatever it does not implement.

That is not a guess. It is the load the language already carries: a
5188-line self-hosting compiler with a self-referential AST, arena
allocation, hash maps and a complete LLVM binding.

**Suits it:** interpreters, compilers, parsers, serialisers, CLI tools,
data-structure libraries, anything driving a C API.

**Does not:** numerics, because float arithmetic is unimplemented; string-heavy code,
because the absence of arrays makes buffer work verbose; anything wanting
to abstract over types.

---

## What could come next

### The two that unblock the most

1. **Arrays and indexing.** `I32 a[8]` and `a[i]`. The largest ergonomic
   gap: every buffer in `lib/` is `malloc` plus hand-written pointer
   arithmetic.

2. **Float arithmetic.** Small and self-contained — `gen_binop` needs to
   select `FAdd`/`FSub`/`FMul`/`FDiv`/`FCmp` when the operands are floats.
   The checker already refuses it, so this is about lifting a restriction
   rather than fixing a silent miscompile.

### Then the language grows

* **Generics and `IFACE`** — what `examples/vector.pl` has always been a
  sketch of, and what would let `lib/vec.pl` stop being `@ABYSS` plus
  an element size.
* **`SWITCH`** — ergonomics for the dispatch sites now written as `ELIF`
  chains.
* **A real module system**, so `!USES` stops being textual inclusion.

### And the compiler itself

* The emitted IR is unoptimised, with every local in memory. Running
  `mem2reg` alone would transform it.
* Diagnostics carry a line and column but no source excerpt.
* No incremental compilation, no debug info.
* **Fold the differential test into `test/run.sh`.** The C and PLUM
  compilers currently emit byte-identical IR on all 28 tests. That is a
  strong invariant, and it should be enforced rather than spot-checked.
