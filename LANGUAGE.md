# PLUM — the language

What the compiler accepts today, what it does not, and what could come next.
Everything here was checked against `src/` and the tests, not against the
grammar sketch in `syntax/plum.ebnf`, which has drifted.
`examples/logger/` uses nearly all of it in one small project.

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

TYPE Reg: ENUM
 | CR = 0x40                ; given
 | SR                       ; one past the last: 0x41
 | ALL = 0xFFFF_FFFF        ; any 32-bit pattern, or negative: = -1
 \_

TYPE MyInt: @I32          ; alias
```

Structs may reference one another and themselves, so `@Node next` inside
`TYPE Node` works. A union overlays every member at one address. Enum
constants are `I32`, numbered from zero unless given, each one past the
one before, as in C. `STRUCT` may be left out: a `TYPE Foo:` followed
directly by fields is a struct. Blank lines and comments may sit between
fields and constants.

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

A whole array cannot be assigned, but a declaration can give its
elements, `I32 a{4} = [ 1 | 2 ]` (see Initialisers). Array parameters are
written as pointers. There is no bounds checking.

### CONST and VOLATILE

A qualifier belongs to the level it is written at, as in C: before the
type it qualifies what is declared; after an `@`, what that pointer points
at.

| PLUM | C |
|---|---|
| `VOLATILE U32 x` | `volatile uint32_t x` |
| `@VOLATILE U32 p` | `volatile uint32_t *p` |
| `VOLATILE @U32 p` | `uint32_t *volatile p` |
| `CONST @VOLATILE Regs r` | `volatile Regs *const r` |

```plum
CONST @VOLATILE GPIORegs GPIOA = 0x50000000 AS @VOLATILE GPIORegs
 | GPIOA.ODR = GPIOA.ODR ^ (1 << 5)        ; two volatile accesses, kept at -O2
```

* **`VOLATILE`**: every load and store through that level is a volatile
  LLVM access, so the optimiser keeps each one, in order. A field of a
  volatile struct is volatile. Memory-mapped registers need it.
* **`CONST`**: the level cannot be assigned. A `CONST` variable needs its
  value where it is declared; a `CONST` global is read-only memory
  (`.rodata`, or flash). `@x` of a `CONST x` is a `@CONST` pointer.
* **Neither is dropped silently.** `@CONST T` and `@VOLATILE T` do not
  convert to `@T`; adding a qualifier is always fine. `AS` drops one on
  purpose.
* **Methods** take the object's qualifiers from their interface's
  receiver. An interface written for `[ @CONST PinData me ]` cannot write
  through `me`, and its methods can be called on a `CONST Pin`; one
  written for a plain `me` cannot be. `VOLATILE` likewise.

### Layout: PACKED, ALIGN, OFFSET, STATIC_ASSERT

```plum
TYPE PersistentHeader: STRUCT
 + PACKED                         ; no padding: 11 bytes
 | U32 magic
 | U16 version
 | U8  flags
 | U32 crc
 \_

TYPE DMABlock: STRUCT
 + ALIGN 32                       ; 32-aligned, and a multiple of 32 long
 | U8 data{64}
 \_

STATIC_ASSERT [ SIZE [ PersistentHeader ] == 11 ]
STATIC_ASSERT [ OFFSET [ PersistentHeader.crc ] == 7 | "crc right after flags" ]
```

* **`+ PACKED`** and **`+ ALIGN N`** are lines of a `STRUCT` or `UNION`
  body. A packed struct's fields are read and written a byte at a time's
  alignment, so an odd offset is safe even where the CPU faults on
  misalignment (Cortex-M0). `ALIGN` takes a power of two up to 4096 and
  holds wherever the type is: global, local, array element, field.
  Together they are not supported yet, nor `ALIGN 16` on ARM, whose data
  layout gives the padding LLVM would use only 8 -- both are errors.
* **`OFFSET [ Type.field ]`** is the byte offset of a field, a `USIZE`
  constant like `SIZE`; the path may go through nested structs,
  `OFFSET [ Outer.inner.x ]`, but not through pointers.
* **`STATIC_ASSERT [ condition ]`**, or `[ condition | "message" ]`, at
  the top level: checked while compiling, with the target's real layout,
  and gone afterwards. The condition is made of literals, enum
  constants, `SIZE`, `OFFSET`, and operators on them.

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
  pointer. Sections start with `+ PUBLIC:`, `+ PRIVATE:` or
  `+ ANONYMOUS:`; methods before any section are public. A `REQ [ ... ]`
  may follow the header, described below.
* **A `CLASS`** is a new struct with its base's fields, plus the methods
  of every `IFACE` it lists after `IMPL`. The base must be the struct each
  interface names as its receiver.
* **Method calls** are `(obj.method)[ args ]`. `obj` may be the object or a
  pointer to it; either way the method receives its address. A call on a
  temporary, like `(((make)[]).method)[]`, works too.
* **`PRIVATE`** methods can only be called from methods of the same class,
  whichever of its interfaces they come from.
* **`REQ`** says what an interface needs, on the header line or on the
  lines under it; the list may span lines. Three kinds of item:

  | item | means |
  |---|---|
  | `I32 hp` | the class's struct has field `hp`, of exactly that type |
  | `Named<T>` | the class taking this interface also takes `Named<T>` |
  | `BUS IMPL SPIBus<BUS>` | the type put for `BUS` is a class taking `SPIBus<BUS>` |

  ```plum
  IFACE MRAMOps<T | BUS>: [ @T me ]
      REQ [
          @BUS bus |
          Named<T> |
          BUS IMPL SPIBus<BUS>
      ]
  ```

  They are checked when a class takes the interface, before any method
  body. A plain class is told so at its `IMPL`, an instance of a generic
  class at the use that made it:
  ``error: `Coin` cannot IMPL Mortal<CoinData>: it has no field `hp` (I32)``.
  A class and the struct it holds count as one: `SPIBus<FakeBus>` is met
  by a class that takes `SPIBus<FakeBusData>`.

  A `REQ` is also the whole contract: the interface's methods use only
  what it lists. Of the class (or the struct it holds) they may use the
  fields it lists and the methods of the interface itself -- required ones
  too -- and of each interface it names; of what a parameter stands for,
  only the methods of the interface the REQ says it `IMPL`s, and no fields
  at all. Everything else is an error where it is used, as a field, a
  method call, a method pointer or an `OFFSET`:
  ``error: the REQ of Collector does not list `score`, a field of `Player` ``.
  Nothing is inherited: needing `Mortal<T>` gives `Mortal`'s methods, not
  those of what `Mortal` itself needs. An interface with no `REQ` is not
  limited. Other types the body meets, such as a `@Coin` parameter, are
  not the contract's business -- unless one is the very type a parameter
  stands for.
* **Required methods.** A method written with no body is required: the
  interface needs it, and another interface of the same class must give
  it, with exactly that signature -- return type, parameters, `...` and
  `ANONYMOUS` alike. Methods with bodies may call it through `me`.

  ```plum
  IFACE SPIBus<T>: [ @T me ]
   | U8 transfer: [ U8 value ]              ; required: no body
   | U8 ping: []                            ; given, and built on it
   |  | RET [ (me.transfer)[ 0 ] ]
   |  \_
   \_

  CLASS LoopBus: LoopData IMPL [ SPIBus<LoopData> | LoopOps<LoopData> ]
  ```

  So one contract has many implementations, each chosen at compile time;
  with `REQ [ BUS IMPL SPIBus<BUS> ]`, a driver works on any of them.
  There is no overriding: a body is an implementation, and two bodies for
  one method are still an error. A class that leaves a requirement unmet
  is told so at its `IMPL`, or a generic one at the use that made it.
  A class and the struct it holds count as one here as in `REQ`.
* **`ANONYMOUS`** methods have no `me`: they belong to the type, not to an
  object, and are called on the type. Constructors are what they are for:

  ```plum
  IFACE OptOps<T>: [ @OptData<T> me ]
   + ANONYMOUS:
   | Opt<T> some: [ T v ]
   |  | Opt<T> r
   |  | r.has = TRUE
   |  | r.value = v
   |  | RET [ r ]
   |  \_
   \_

   | Opt<I32> a = (Opt<I32>.some)[ 7 ]      ; a generic class, with its arguments
   | Point p = (Point.at)[ 2 | 3 ]          ; a plain class, by its name
  ```

  Inside an interface, `(Opt<T>.none)[]` names the class being built. An
  `ANONYMOUS` method cannot be called on an object, nor an ordinary one on
  the type, and `me` in one is an error. A type written in an expression
  is only ever the left side of such a call, or of a method pointer.
* **Method pointers.** `Type.method` outside a call is the method's
  address, as a function's name is. An ordinary method takes the
  object's address first, as `me`; an `ANONYMOUS` one only its own
  parameters:

  ```plum
   | FN ABYSS [ @Foo ] show = Foo.show     ; (show)[ @f ]
   | FN I32 [ @Foo | I32 ] add = Foo.add   ; (add)[ @f | 1 ]
   | FN Foo [ I32 ] make = Foo.at          ; ANONYMOUS: (make)[ 5 ]
   | FN Box<I32> [ I32 ] b = Box<I32>.of   ; a generic class's, with its arguments
  ```

  `f.show` is an error: a method bound to its object would be a closure,
  which one C pointer cannot hold. `PRIVATE` methods can be taken only
  where they can be called.
* **Generic functions** take type parameters after their name, and are
  used with the arguments written out -- they are not inferred:

  ```plum
  T max<T>: [ T a | T b ]
   | IF [ a > b ]
   |  | RET [ a ]
   |  \_
   | RET [ b ]
   \_

  B1 less<T>: [ @T a | @T b ]
      REQ [ T IMPL Ord<T> ]
   | RET [ (a.cmp)[ b ] < 0 ]
   \_

   | I32 m = (max<I32>)[ 3 | 7 ]
   | FN I32 [ I32 | I32 ] f = max<I32>     ; a pointer to that copy
   | B1 lt = (less<Num>)[ @a | @b ]
  ```

  Each distinct use makes one ordinary function, named `max<I32>`; one
  may call itself, as `(fact<T>)[ n - 1 ]`, and a generic class's methods
  may use one with their own parameters, `(max<T>)[ ... ]`. A generic
  function needs a body. Its `REQ` only says what the type parameters
  `IMPL`, is checked at each use -- ``error: `less<P>` cannot be made: it
  needs P to IMPL Ord<P>, and P is not a CLASS`` -- and is a full contract
  as an interface's is: on a `T` the body may call only `Ord`'s methods,
  and use no field. Without a `REQ`, the body is checked per copy, and an
  error shows at the copy that has it.
* **`NULL`** is the null pointer.

This is all compile time. Every distinct use such as `Vector<I32>` is
instantiated once, as a struct named `Vector<I32>` and functions named
`Vector<I32>.push`; these names appear as-is in the emitted IR. An
interface's body is only checked when some class uses it. There are no
interface-typed values and no dynamic dispatch built in; a struct of
function pointers does it by hand, as `examples/interfaces.pl` shows.

`src/generic.pl` does the instantiation, between parsing and `meta`;
everything after it sees only ordinary types and functions.

---

## Declarations

```plum
I32 puts: [ @C1 str ]                 ; declaration only = extern C function
I32 printf: [ @C1 fmt | ... ]         ; varargs
I32 counter = 0                       ; global; initialised by a constant
I32 MASK = (1 << 4) - 1               ;   expression: literals, enum constants,
FN I32 [ I32 | I32 ] OP = add         ;   SIZE, OFFSET, function names, arithmetic
CONST I32 LIMIT = 10                  ; read-only: .rodata, or flash

I32 add: [ I32 a | I32 b ]            ; declaration + block = definition
 | RET [ a + b ]
 \_
```

Structs pass and return **by value**. Recursion works. Everything lives at
the top level — no nested functions and no modules. Methods live in an
`IFACE`, described above.

### Initialisers

```plum
TYPE Point: STRUCT
 | I32 x
 | I32 y
 \_

CONST U32 TABLE{8} = [ 1 | 2 | 4 | 8 ]       ; the other four are 0
CONST Line ORIGIN = [ .b = [ 7 | 8 ] | .tag = "origin" ]
@C1 NAMES{3} = [
    "zero" |
    "one" |
    "two"
]

 | Point p = [ .y = 2 | .x = 1 ]      ; by name, in any order
 | Point q = [ 3 ]                    ; in order: x = 3, y = 0
 | Point ps{2} = [ [ 1 | 2 ] | [ .y = 4 ] ]
 | Val v = [ .f = 1.5 ]               ; a UNION: one field
```

`[ ... ]` goes after the `=` of a declaration, local or global, whose
type says what it builds: an array's elements in order, a struct's fields
in order or all by name, a union's one field. Values nest, and whatever
is left out is zero. A global's values must be constants, and a global
`UNION` cannot take one yet. The list may run over several lines.

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
 | n += 1                        also -= *= /= %= &= |= ^= <<= >>=
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
 | FOR [ I32 i = 0 | i < n | i += 1 ]
 |  | ...                         the step runs after CONTINUE too
 |  \_
 |
 | SWITCH [ kind ]
 | CASE [ K_NUM ]                CASE lines sit at the SWITCH's depth
 |  | ...
 | CASE [ K_ADD | K_SUB ]        any of several constants
 |  | ...
 | ELSE                          optional
 |  | ...
 |  \_
 |
 | POSTLUDE (buf.deinit)[]       run when this block is left, however
 |
 | BREAK
 | CONTINUE
 | RET [ expr ]                  also  RET []  and bare  RET
```

**`FOR [ init | cond | step ]`** is `init`, then a `WHILE [ cond ]` whose
every pass, `CONTINUE`d or not, ends with `step`. A variable `init`
declares belongs to the loop.

**`SWITCH`** compares an integer or an enum with each `CASE`'s constants
-- literals, characters, enum constants, `-` or `~` of one -- and runs the
one block that matches, or the `ELSE`. There is no fallthrough; `BREAK`
and `CONTINUE` inside act on the loop around the `SWITCH`. A value may
appear in one `CASE` only. On a value of an `ENUM` type, a `SWITCH`
without `ELSE` must have a `CASE` for every constant:
``error: this SWITCH on `Color` has no CASE for `BLUE`; add one, or an
ELSE``. Only a `SWITCH` with an `ELSE` counts as always leaving a function
that every branch `RET`s from: a value no `CASE` names falls through.

**`POSTLUDE stmt`**, or `POSTLUDE` over a block, runs when the block it is
in is left: at its end, or by `RET`, `BREAK` or `CONTINUE`. Several run
last-written first, each seeing the names it saw where it was written.
A `RET`'s value is worked out before they run, so `RET [ s.len ]` then a
`POSTLUDE (s.deinit)[]` is safe. A `POSTLUDE`'s statement cannot itself
`RET`, or `BREAK` or `CONTINUE` out of it.

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
| Offset | `OFFSET [ T.field ]`, through nested structs: `OFFSET [ Outer.in.x ]` |

Member chains go as deep as needed, through pointers and unions alike:
`n.as.bin_op.left.as.literal.as.int_lit`.

Casts are deliberately more permissive than implicit conversion: int to
pointer, pointer to pointer, width changes, int to float. That is what
makes a `malloc` result usable as a typed pointer.

### Precedence, tightest first

```
prefix  ? @ - ! ~
.  {}
AS
* / %
+ -
<< >>
< <= > >=
&
^
== !=
|
&&
||
=
```

Three consequences worth memorising:

* **Prefix binds tighter than `.`**, the opposite of C. `@s.f` groups as
  `(@s).f`, so a field's address is written `@(s.f)`. Dereference works out
  in your favour: `?p.f` is `(?p).f`, which is C's `p->f`.
* **`&`, `^` and `|` bind tighter than comparisons and `&&`**, unlike C:
  `x & MASK == 0` is `(x & MASK) == 0`, which is usually what is meant,
  and `a | b && c` is `(a | b) && c`.
* **Inside an argument list a bare `|` separates arguments.** A bitwise-or
  there needs parentheses: `(f)[ (a | b) ]`. Every other operator, `&&`
  and `||` included, works as usual. Everywhere else — initialisers,
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
  twice with different signatures; a field, parameter or enum constant
  named twice
* an alias of itself (`TYPE A: B` with `TYPE B: A`), and a struct that
  holds itself by value, directly or through another
* an integer divided by a literal `0`
* global initialisers, checked as a local's are
* assigning to something `CONST`, a `CONST` without its value, a pointer
  dropping `CONST` or `VOLATILE`, and a method called on a `CONST` or
  `VOLATILE` object whose interface's `me` is not
* `OFFSET` of a field that is not there or behind a pointer, and a
  `STATIC_ASSERT` condition that is not an integer or `B1`
* everything about `IFACE`, `CLASS` and generics listed in their section:
  unmet `REQ`s and required methods, a body using what its `REQ` does not
  list, `ANONYMOUS` misuse, `PRIVATE` calls

Some layout errors need the target's data layout, so codegen reports
them: a `STATIC_ASSERT` that does not hold, `ALIGN` the target cannot
give, and `PACKED` with `ALIGN` on one type.

It deliberately does *not* flag mixing signed and unsigned, or narrowing
an integer, since PLUM's implicit coercion already defines those.

`test/typecheck/` holds one program per rejection, each a bug that was
once accepted silently.

## What PLUM cannot express

| Missing | Workaround |
|---|---|
| Multidimensional arrays | index a flat one: `grid{y * w + x}` |
| Ternary `?:` | `IF` |
| `++` / `--` | `+= 1` |
| `va_arg` (reading varargs one by one) | pass them on with `...` to a C `v` function |
| Interface-typed values, dynamic dispatch | a struct of function pointers, as `examples/interfaces.pl`; at compile time, required methods and `REQ` |
| Sum types, pattern matching | a generic class with a tag: `Option` and `Result` in `examples/` |
| `SECTION`, `USED`, `WEAK`, `NORETURN`, `INLINE` | `--data-sections` and a linker script, as `examples/stm32g071/` does |
| Compile-time evaluation (`COMPTIME`) | `STATIC_ASSERT` for checks; tables computed at start-up |
| Modules, namespaces | none |
| Closures, exceptions | none |


Calling a variadic function works, and so does passing its arguments on:
inside a function taking `...`, a call's last argument may be `...`, which
hands them to C's `v` functions as one `va_list` -- declared there as
`@ABYSS`:

```plum
I32 vfprintf: [ @ABYSS f | @C1 fmt | @ABYSS ap ]
ABYSS error: [ @C1 fmt | ... ]
 | (vfprintf)[ stderr | fmt | ... ]
 \_
```

Only reading them one by one, C's `va_arg`, is absent.

---

## What it is good for

The shape PLUM fits is a systems program built from tagged unions and
explicit memory, calling out to C for whatever it does not implement --
and, with `VOLATILE`, `PACKED`, `ALIGN` and `--target`, firmware.

That is not a guess. It is the load the language already carries: an
11,500-line self-hosting compiler with a self-referential AST, arena
allocation, hash maps, a complete LLVM binding and a language server;
and STM32 firmware, startup code included, with no C at all
(`examples/stm32g071/`).

**Suits it:** interpreters, compilers, parsers, serialisers, CLI tools,
data-structure libraries, drivers and firmware, anything driving a C API.

**Does not yet:** large code bases, which want modules; debugging, which
wants debug info (see below).

---

## What could come next

### The language

`examples/future.pl` sketches the direction; in rough order:

* **Attributes** — `SECTION`, `USED`, `WEAK`, `NORETURN`, `INLINE`: with
  them and initialisers a vector table is written as data, and
  `examples/stm32g071/startup.pl` loses its last hacks.
* **`COMPTIME`**: ordinary PLUM run by the compiler, for tables.
* **A real module system**, `!USES <gpio.pl> AS gpio`, so `!USES` stops
  being textual inclusion.
* **The rest of `lib/` onto generics.** `lib/vector.pl` is a typed
  `Vector<T>` and `lib/string.pl` a `String` class, and the compiler uses
  both; `map.pl` (still `@ABYSS` values) and `stack.pl` are next.

Deliberately not planned: garbage collection, a borrow checker,
exceptions, runtime interfaces, and sum types with pattern matching.

### And the compiler itself

* `-O0` is the default, with every local in memory; `-O1` to `-O3` run
  LLVM's standard pipeline. `--emit=OBJ` writes machine code, for any
  `--target`, but linking is still the system linker's job.
* Diagnostics show the file, line, column and the source line with a
  caret, on stderr. The parser still stops at its first error; the type
  checker reports them all. `plc --lsp` serves them to an editor, with
  go to definition and hover.
* No incremental compilation, no debug info.
* The C compiler is frozen, and PLUM has since diverged from it (literal
  widths, truth values, generics and the rest), so the two no longer emit
  the same IR. The evidence now is `test/*/*.out`: every test's output
  and exit code, checked on every run.
