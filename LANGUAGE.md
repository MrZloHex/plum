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
| `F32` `F64` | floats — IEEE single and double, with full arithmetic |
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
constants are `I32`, numbered from zero. `STRUCT` may be left out: a
`TYPE Foo:` followed directly by fields is a struct.

### Arrays

```plum
I32 squares{10}                       ; global, zero-initialised
TYPE Name:
 | C1  text{16}                       ; inside a struct, laid out inline
 | I32 len
 \_

I32 main: []
 | C1 buf{32}                         ; local
 | buf{0} = 'h'
 | (puts)[ buf ]                      ; decays to @C1, as in C
 | @I32 p = (malloc)[ 16 ] AS @I32
 | p{3} = squares{2}                  ; pointers index the same way
 \_
```

`T name{N}` declares an array of `N` elements; `N` is an integer literal.
`x{i}` is the element `i` places past what `x` points at -- exactly
`?(x + i)` -- and works on arrays and pointers alike. Used as a value, an
array is a pointer to its first element: it passes to `@T` parameters, and
`buf + 2`, `?buf` and `@buf` behave as in C. Indexing binds like `.`, so
`pts{1}.x` and `s.text{0}` read left to right.

A whole array cannot be assigned or given an initialiser; assign its
elements. Array parameters are written as pointers. There is no bounds
checking.

### Floats

`+ - * / %` and every comparison work on `F32` and `F64`, as do unary `-`
and `!`. An integer operand is converted to the float's type (unsigned
ones as unsigned), and `F32` with `F64` widens to `F64`. A float literal is
an `F64`; storing it into an `F32` rounds it. Comparisons follow C for NaN:
only `!=` is true. Floats passed to a variadic function such as `printf`
are promoted to `F64`, again as in C. `AS` converts in both directions,
truncating toward zero into integers.

Bitwise operators on floats are rejected. `%` on floats is C's `fmod`, so a
program that uses it needs `-lm` when linking.

---

## Generics, interfaces and classes

```plum
TYPE VectorType<T>:                   ; a generic struct
 | @T    data
 | USIZE size
 | USIZE cap
 \_

IFACE VectorFace<T>: [ @VectorType<T> me ]   ; methods over @VectorType<T>
 + PUBLIC:
 | ABYSS push: [ T v ]
 |  | IF [ me.size == me.cap ]
 |  |  | (me.grow)[]                ; methods call each other through me
 |  |  \_
 |  | ?(me.data + me.size) = v
 |  | me.size += 1
 |  \_
 + PRIVATE:
 | ABYSS grow: []
 |  | ...
 |  \_
 \_

CLASS Vector<T>: VectorType<T> IMPL [ VectorFace<T> ]

I32 main: []
 | Vector<I32> v                       ; v.data, v.size ... are fields
 | (v.push)[ 42 ]                      ; a method call
 | @Vector<I32> p = @v
 | (p.push)[ 43 ]                      ; through a pointer, too
 \_
```

* **Generic types** take parameters in angle brackets, separated by `|`
  like everything else: `TYPE Pair<A | B>:`, used as `Pair<I32 | @C1>`.
  Any `TYPE` can be generic -- struct, union, enum or alias
  (`TYPE Ref<T>: @T`). Arguments may be pointers, other instances, or
  nested: `Vector<Vector<I32>>` (a `>>` closes both lists).
* **An `IFACE`** is a set of methods written against one receiver, named
  in its header: `[ @VectorType<T> me ]`. Every method gets `me` as a
  pointer. Sections start with `+ PUBLIC:` or `+ PRIVATE:`; methods before
  any section are public.
* **A `CLASS`** is a new struct with its base's fields, plus the methods
  of every `IFACE` it lists after `IMPL`. The base must be the struct each
  interface names as its receiver.
* **Method calls** are `(obj.method)[ args ]`. `obj` may be the object or a
  pointer to it; either way the method receives its address. A call on a
  temporary, like `(((make)[]).method)[]`, works too.
* **`PRIVATE`** methods can only be called from methods of the same class,
  whichever of its interfaces they come from.
* **`NULL`** is the null pointer.

This is all compile time. Every distinct use such as `Vector<I32>` is
instantiated once, as a struct named `Vector<I32>` and functions named
`Vector<I32>.push`; these names appear as-is in the emitted IR. An
interface's body is only checked when some class uses it. There are no
interface-typed values and no dynamic dispatch, since PLUM has no function
pointers.

`src/generic.pl` does the instantiation, between parsing and `meta`;
everything after it sees only ordinary types and functions.

---

## Declarations

```plum
I32 puts: [ @C1 str ]                 ; declaration only = extern C function
I32 printf: [ @C1 fmt | ... ]         ; varargs
I32 counter = 0                       ; global; initialised by a constant
I32 MASK = (1 << 4) - 1               ;   expression: literals, enum constants,
FN I32 [ I32 | I32 ] OP = add         ;   SIZE, function names, arithmetic

I32 add: [ I32 a | I32 b ]            ; declaration + block = definition
 | RET [ a + b ]
 \_
```

Structs pass and return **by value**. Recursion works. Everything lives at
the top level — no nested functions and no modules. Methods live in an
`IFACE`, described below.

### Function pointers

```plum
TYPE BinOp: FN I32 [ I32 | I32 ]      ; FN <return> [ <params> ]

I32 fold: [ @I32 xs | I32 n | I32 acc | BinOp f ]
 | ...
 |  | acc = (f)[ acc | xs{i} ]        ; called like a function
 \_

 | FN I32 [ I32 | I32 ] op = add       ; a function's name is its address
 | BinOp table{3}                      ; arrays of them
 | (table{1})[ 6 | 3 ]                 ; call any expression that yields one
 | ((pick)[ '+' ])[ 40 | 2 ]
 | (shape.area)[ @shape ]              ; a field: a vtable by hand
```

`FN R [ P | Q ]` is a pointer to a function taking `P` and `Q` and
returning `R`; parameter names may be written and are ignored, and `...`
makes it variadic. It is one machine pointer, C-compatible, so C
callbacks such as `qsort`'s comparator take PLUM functions directly.

A function pointer accepts only a function of exactly its signature, or
`NULL`; it compares with `==`, and is true when non-null. `(name)[ ... ]`
calls a variable holding a function pointer if one is in scope, and the
function of that name otherwise. `(obj.name)[ ... ]` calls a method if the
class has one, and a function-pointer field otherwise.

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
`"text\n"`, `TRUE`, `FALSE`, `NULL`, `1.5`, `1e3`, `2.5e-2`, `6.02E+23`.
`_` separates digits in every kind of number. An integer literal is an `I32` when it
fits and 64 bits otherwise, so `0xDEAD_BEEF_CAFE_F00D` keeps every bit.

**Truth** — a condition, `!`, `&&`, `||` and conversion to `B1` all mean
"not zero" (for pointers, "not NULL"). `TRUE` converts to the integer 1.
Unsigned integers widen with zeros, signed ones with their sign.

| Group | Operators |
|---|---|
| Arithmetic | `+` `-` `*` `/` `%` — signed or unsigned per operand type, float when either side is |
| Bitwise | `&` `\|` `^` `~` `<<` `>>` |
| Comparison | `==` `!=` `<` `<=` `>` `>=` |
| Logical | `&&` `\|\|` `!` — genuinely short-circuiting |
| Pointers | `?p` dereference, `@x` address-of, `p + n` scaled by element size, `p - q` counts elements, `@ABYSS` moves by bytes |
| Indexing | `a{i}`, on arrays and pointers |
| Members | `s.field`, auto-dereferencing through pointers |
| Calls | `(name)[ arg \| arg ]`, methods `(obj.name)[ arg ]` |
| Casts | `expr AS T` |
| Size | `SIZE [ T ]`, any type: `SIZE [ @C1 ]`, `SIZE [ Pair<I32 \| I8> ]` |

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
triggering it. Each file is included **once**: later directives naming the
same file, by any path, expand to nothing. PLUM declarations do not depend
on order, so no guards are needed.

**C interop** needs no binding layer. Declare the function and call it.
Opaque handles travel as `@ABYSS`, which is how the compiler's own backend
drives the entire LLVM-C API.

---

## The type checker

`src/check.pl` runs between `meta` and `codegen`. It only ever
rejects; it never changes what is emitted, so a program that passes
compiles exactly as it did before the checker existed.

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
* a bitwise operator on a float, and a float used as an index
* indexing something that is neither an array nor a pointer
* assigning to, or initialising, a whole array
* assigning to, or taking `@` of, something that is not stored anywhere:
  a literal, a call's result, a function, an enum constant
* using the result of an `ABYSS` call as a value
* pointer arithmetic other than `p + n`, `n + p`, `p - n` and `p - q`
  (which needs both pointers to the same type), and `-`/`~` on a pointer
* dereferencing or indexing `@ABYSS` before casting it
* casting a struct, and `SIZE [ ABYSS ]`
* a value-returning function that can reach its end without `RET`
  (`main` is exempt and returns 0, as in C)
* `BREAK` or `CONTINUE` outside a loop
* a TYPE, function or global defined twice, or a function declared
  twice with different signatures
* everything about `IFACE`, `CLASS` and generics listed in their section

It deliberately does *not* flag mixing signed and unsigned, or narrowing
an integer, since PLUM's implicit coercion already defines those.

`test/typecheck/` holds one program per rejection, each a bug that was
once accepted silently.

## What PLUM cannot express

| Missing | Workaround |
|---|---|
| Array initialisers, `I32 a{3} = ...` | assign the elements |
| Multidimensional arrays | index a flat one: `grid{y * w + x}` |
| `switch` | `ELIF` chains |
| Ternary `?:` | `IF` |
| `for` | `WHILE` |
| `++` / `--` | `+= 1` |
| `va_arg` (consuming varargs) | none — callers format first, as `src/trace.pl` does |
| Generic functions | a method of a generic `CLASS` |
| Interface-typed values, dynamic dispatch | none; an `IFACE` is compile time only |
| Sum types, `Option<T>` | a generic struct with a tag, or a `B1` result plus an out-pointer |
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

**Does not yet:** heavy numerics, because every local lives in memory and
the IR is unoptimised (see below).

---

## What could come next

### The language

* **Sum types** — `ENUM Option<T>` with payloads, which is what the
  `get` in `examples/vector.pl` returns. Generics are in place, so this is
  the tag, the payload union and a way to take them apart.
* **The rest of `lib/` onto generics.** `lib/vector.pl` is a typed
  `Vector<T>` and the compiler's own tables use it; `map.pl` (still
  `@ABYSS` values) and `stack.pl` are next, and `vec.pl` can then go.
* **`SWITCH`** — ergonomics for the dispatch sites now written as `ELIF`
  chains.
* **A real module system**, so `!USES` stops being textual inclusion.

### And the compiler itself

* The emitted IR is unoptimised, with every local in memory. Running
  `mem2reg` alone would transform it.
* Diagnostics show the file, line, column and the source line with a
  caret, on stderr. The parser still stops at its first error; the type
  checker reports them all.
* No incremental compilation, no debug info.
* The C compiler is frozen, and PLUM has since diverged from it (literal
  widths, truth values, generics and the rest), so the two no longer emit
  the same IR. The evidence now is `test/*/*.out`: every test's output
  and exit code, checked on every run.
