; Generic corners: >>> closing three lists, a generic UNION, an IFACE whose
; receiver is the class itself, classes inside generic types and arrays of
; them, a method returning a struct by value, a global of a class type.

!USES <../../extern/stdio.pl>

TYPE Box<T>:
 | T v
 \_

; three levels deep, closed by >>>
Box<Box<Box<I32>>> deep

; generic union and enum
TYPE Either<A | B>: UNION
 | A left
 | B right
 \_

; receiver is the class itself
TYPE CData<T>:
 | T n
 \_
IFACE SelfFace<T>: [ @Counter<T> self ]
 | T get: []
 |  | RET [ self.n ]
 |  \_
 | ABYSS set: [ T x ]
 |  | self.n = x
 |  \_
 \_
CLASS Counter<T>: CData<T> IMPL [ SelfFace<T> ]

; a class used inside another generic
TYPE Holder<T>:
 | Counter<T> c
 | Counter<T> cs{2}
 \_

; a generic method returning a struct by value
IFACE Wrap<T>: [ @CData<T> me ]
 | Box<T> boxed: []
 |  | Box<T> b
 |  | b.v = me.n
 |  | RET [ b ]
 |  \_
 \_
CLASS W<T>: CData<T> IMPL [ Wrap<T> ]

Counter<F64> gc

I32 main: []
 | deep.v.v.v = 7
 | (printf)[ "deep %d, size %d\n" | deep.v.v.v | SIZE [ Box<Box<Box<I32>>> ] AS I32 ]
 |
 | Either<I32 | F32> e
 | e.right = 1.5
 | (printf)[ "either %d bytes, right %.1f\n" | SIZE [ Either<I32 | F32> ] AS I32 | e.right ]
 |
 | Holder<I32> h
 | (h.c.set)[ 5 ]
 | (h.cs{1}.set)[ 6 ]
 | (printf)[ "holder %d %d\n" | (h.c.get)[] | (h.cs{1}.get)[] ]
 |
 | (gc.set)[ 2.25 ]
 | (printf)[ "global class %.2f\n" | (gc.get)[] ]
 |
 | W<C1> w
 | w.n = 'q'
 | (printf)[ "boxed %c, via temp %c\n" | ((w.boxed)[]).v | ((w.boxed)[]).v ]
 |
 | @Counter<I32> pc = @(h.c)
 | (pc.set)[ 9 ]
 | (printf)[ "through pointer %d\n" | (h.c.get)[] ]
 | RET [ 0 ]
 \_
