; ANONYMOUS methods: no `me`, called on the type -- constructors, mostly

!USES <../../extern/stdio.pl>

TYPE OptData<T>: STRUCT
 | B1 has
 | T  value
 \_

IFACE OptOps<T>: [ @OptData<T> me ]
 | T or: [ T dflt ]
 |  | IF [ me.has ]
 |  |  | RET [ me.value ]
 |  |  \_
 |  | RET [ dflt ]
 |  \_
 + ANONYMOUS:
 | Opt<T> some: [ T v ]
 |  | Opt<T> r
 |  | r.has = TRUE
 |  | r.value = v
 |  | RET [ r ]
 |  \_
 | Opt<T> none: []
 |  | Opt<T> r
 |  | r.has = FALSE
 |  | RET [ r ]
 |  \_
 | ; one ANONYMOUS method calling another, with T still a parameter
 | Opt<T> when: [ B1 cond | T v ]
 |  | IF [ cond ]
 |  |  | RET [ (Opt<T>.some)[ v ] ]
 |  |  \_
 |  | RET [ (Opt<T>.none)[] ]
 |  \_
 \_

CLASS Opt<T>: OptData<T> IMPL [ OptOps<T> ]

; a class without parameters: its name alone is the type
TYPE PointData: STRUCT
 | I32 x
 | I32 y
 \_

IFACE PointOps: [ @PointData me ]
 | I32 sum: []
 |  | RET [ me.x + me.y ]
 |  \_
 + ANONYMOUS:
 | Point at: [ I32 x | I32 y ]
 |  | Point p
 |  | p.x = x
 |  | p.y = y
 |  | RET [ p ]
 |  \_
 | Point origin: []
 |  | RET [ (Point.at)[ 0 | 0 ] ]
 |  \_
 \_

CLASS Point: PointData IMPL [ PointOps ]

Opt<I32> half: [ I32 n ]
 | RET [ (Opt<I32>.when)[ n % 2 == 0 | n / 2 ] ]
 \_

I32 main: []
 | Opt<I32> a = (Opt<I32>.some)[ 7 ]
 | Opt<I32> b = (Opt<I32>.none)[]
 | (printf)[ "%d %d\n" | (a.or)[ -1 ] | (b.or)[ -1 ] ]                  ; 7 -1
 | (printf)[ "%d %d\n" | ((half)[ 10 ].or)[ -1 ] | ((half)[ 7 ].or)[ -1 ] ]   ; 5 -1
 | (printf)[ "%d\n" | (((Opt<@C1>.some)[ "text" ]).or)[ "none" ] AS I32 != 0 ]   ; 1
 | (printf)[ "%s\n" | (((Opt<@C1>.none)[]).or)[ "fallback" ] ]          ; fallback
 | Opt<Opt<I32>> nested = (Opt<Opt<I32>>.some)[ (Opt<I32>.some)[ 3 ] ]
 | (printf)[ "%d\n" | ((nested.or)[ b ].or)[ 0 ] ]                        ; 3
 | Point p = (Point.at)[ 2 | 3 ]
 | (printf)[ "%d %d\n" | (p.sum)[] | (((Point.origin)[]).sum)[] ]        ; 5 0
 | RET [ 0 ]
 \_
