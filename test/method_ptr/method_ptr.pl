; method_ptr.pl -- Type.method is a function pointer, as a function's name is
I32 printf: [ @C1 fmt | ... ]

TYPE CounterData: STRUCT
 | I32 n
 \_

IFACE CounterOps: [ @CounterData me ]
 | ABYSS show: []
 |  | (printf)[ "n = %d\n" | me.n ]
 |  \_
 | I32 add: [ I32 k ]
 |  | me.n += k
 |  | RET [ me.n ]
 |  \_
 + ANONYMOUS:
 | Counter at: [ I32 n ]
 |  | Counter c
 |  | c.n = n
 |  | RET [ c ]
 |  \_
 \_

CLASS Counter: CounterData IMPL [ CounterOps ]

TYPE BoxData<T>: STRUCT
 | T v
 \_

IFACE BoxOps<T>: [ @BoxData<T> me ]
 + ANONYMOUS:
 | Box<T> of: [ T v ]
 |  | Box<T> b
 |  | b.v = v
 |  | RET [ b ]
 |  \_
 \_

CLASS Box<T>: BoxData<T> IMPL [ BoxOps<T> ]

TYPE Step: FN I32 [ @Counter | I32 ]

; a global may hold one: it is a constant
FN Counter [ I32 ] MAKE = Counter.at

I32 twice: [ @Counter c | Step f | I32 k ]
 | (f)[ c | k ]
 | RET [ (f)[ c | k ] ]
 \_

I32 main: []
 | ; an ANONYMOUS method takes only its own parameters
 | Counter c = (MAKE)[ 5 ]
 |
 | ; an ordinary one takes the object's address first, as `me`
 | FN ABYSS [ @Counter ] show = Counter.show
 | (show)[ @c ]
 | (printf)[ "twice: %d\n" | (twice)[ @c | Counter.add | 10 ] ]
 | (show)[ @c ]
 |
 | Step table{2}
 | table{0} = Counter.add
 | table{1} = NULL
 | (printf)[ "table: %d, %d\n" | (table{0})[ @c | 1 ] | table{1} == NULL ]
 | (printf)[ "same: %d\n" | table{0} == Counter.add ]
 |
 | ; a generic class's, with its arguments
 | FN Box<I32> [ I32 ] box = Box<I32>.of
 | (printf)[ "box: %d\n" | ((box)[ 42 ]).v ]
 | RET [ 0 ]
 \_
