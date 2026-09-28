; REQ: what an interface needs of the class that takes it

!USES <../../extern/stdio.pl>

TYPE Cell<T>: STRUCT
 | T   value
 | I32 hits
 \_

; the field's type depends on the parameter: Cell<I64> needs an I64 value
IFACE Store<T>: [ @Cell<T> me ] REQ [ T value | I32 hits ]
 | ABYSS put: [ T v ]
 |  | me.value = v
 |  | me.hits += 1
 |  \_
 \_

; needs Store as well, and uses it
IFACE Twice<T>: [ @Cell<T> me ] REQ [ Store<T> ]
 | ABYSS put2: [ T v ]
 |  | (me.put)[ v ]
 |  | (me.put)[ v + v ]
 |  \_
 \_

CLASS Counter<T>: Cell<T> IMPL [ Store<T> | Twice<T> ]

I32 main: []
 | Counter<I64> c
 | c.hits = 0
 | (c.put2)[ 21 ]
 | (printf)[ "%ld after %d puts\n" | c.value | c.hits ]      ; 42 after 2 puts
 | Counter<F64> f
 | f.hits = 0
 | (f.put)[ 1.5 ]
 | (printf)[ "%g after %d put\n" | f.value | f.hits ]         ; 1.5 after 1 put
 | RET [ 0 ]
 \_
