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
I32 counter = 0                       ; global, constant initialiser only

I32 add: [ I32 a | I32 b ]            ; declaration + block = definition
 | RET [ a + b ]
 \_
```

Structs pass and return **by value**. Recursion works. Everything lives at
the top level — no nested functions and no modules. Methods live in an
`IFACE`, described below.

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
`"text\n"`, `TRUE`, `FALSE`, `NULL`

| Group | Operators |
|---|---|
| Arithmetic | `+` `-` `*` `/` `%` — signed or unsigned per operand type, float when either side is |
| Bitwise | `&` `\|` `^` `~` `<<` `>>` |
| Comparison | `==` `!=` `<` `<=` `>` `>=` |
| Logical | `&&` `\|\|` `!` — genuinely short-circuiting |
| Pointers | `?p` dereference, `@x` address-of, `p + n` scaled by element size |
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
* a bitwise operator on a float, and a float used as an index
* indexing something that is neither an array nor a pointer
* assigning to, or initialising, a whole array

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
| Function pointers | none |
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
* **Moving `lib/` onto generics**, so `lib/vec.pl` stops being `@ABYSS`
  plus an element size. That needs a seed refresh first; see BOOTSTRAP.md.
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
