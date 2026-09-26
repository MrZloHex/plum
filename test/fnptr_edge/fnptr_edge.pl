; Function pointers taking and returning structs by value, returning
; function pointers, compared, through @FN, and a non-generic CLASS over a
; generic base reached by casting @ABYSS.

!USES <../../extern/stdio.pl>
TYPE V2:
 | I32 x
 | I32 y
 \_
V2 swap: [ V2 v ]
 | V2 r
 | r.x = v.y
 | r.y = v.x
 | RET [ r ]
 \_
I32 one: []
 | RET [ 1 ]
 \_
TYPE Box<T>:
 | T v
 \_
IFACE BoxOps<T>: [ @Box<T> me ]
 | T get: []
 |  | RET [ me.v ]
 |  \_
 \_
CLASS Cell<T>: Box<T> IMPL [ BoxOps<T> ]
FN FN I32 [] [ I32 ] chooser = NULL
FN I32 [] choose: [ I32 k ]
 | RET [ one ]
 \_
I32 main: []
 | FN V2 [ V2 ] f = swap
 | V2 a
 | a.x = 1
 | a.y = 2
 | V2 b = (f)[ a ]
 | (printf)[ "%d %d\n" | b.x | ((f)[ a ]).y ]
 | FN I32 [] g = one
 | IF [ g && g == one && g != NULL ]
 |  | (printf)[ "fn compare ok\n" ]
 |  \_
 | chooser = choose
 | (printf)[ "%d\n" | ((chooser)[ 0 ])[] ]
 | Cell<I32> c
 | c.v = 42
 | @ABYSS raw = @c
 | (printf)[ "%d\n" | ((raw AS @Cell<I32>).get)[] ]
 | @FN I32 [] pg = @g
 | (printf)[ "%d\n" | (?pg)[] ]
 | IntCell ic
 | ic.v = 7
 | (printf)[ "%d\n" | (ic.get)[] ]
 | RET [ 0 ]
 \_

CLASS IntCell: Box<I32> IMPL [ BoxOps<I32> ]
