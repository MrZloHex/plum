; generic_fn.pl -- generic functions: made per use, with REQ on their parameters
I32 printf: [ @C1 fmt | ... ]

T max<T>: [ T a | T b ]
 | IF [ a > b ]
 |  | RET [ a ]
 |  \_
 | RET [ b ]
 \_

ABYSS swap<T>: [ @T a | @T b ]
 | T t = ?a
 | ?a = ?b
 | ?b = t
 \_

T fact<T>: [ T n ]
 | IF [ n <= 1 ]
 |  | RET [ 1 ]
 |  \_
 | RET [ n * (fact<T>)[ n - 1 ] ]
 \_

TYPE NumData: STRUCT
 | I32 v
 | I32 secret
 \_
IFACE Ord<T>: [ @T me ] REQ [ I32 v ]
 | I32 cmp: [ @T o ]
 |  | RET [ me.v - o.v ]
 |  \_
 \_
CLASS Num: NumData IMPL [ Ord<NumData> ]

B1 less<T>: [ @T a | @T b ]
    REQ [ T IMPL Ord<T> ]
 | RET [ (a.cmp)[ b ] < 0 ]
 \_

TYPE BoxData<T>: STRUCT
 | T v
 \_
IFACE BoxOps<T>: [ @BoxData<T> me ]
 | T bigger: [ T o ]
 |  | RET [ (max<T>)[ me.v | o ] ]
 |  \_
 \_
CLASS Box<T>: BoxData<T> IMPL [ BoxOps<T> ]

I32 main: []
 | (printf)[ "%d %d\n" | (max<I32>)[ 3 | 7 ] | (max<I32>)[ -2 | -9 ] ]
 | (printf)[ "%.1f\n" | (max<F64>)[ 1.5 | 0.5 ] ]
 | I32 x = 1
 | I32 y = 2
 | (swap<I32>)[ @x | @y ]
 | (printf)[ "%d %d\n" | x | y ]
 | (printf)[ "%ld\n" | (fact<I64>)[ 10 ] ]
 | FN I32 [ I32 | I32 ] f = max<I32>
 | (printf)[ "%d %d\n" | (f)[ 4 | 5 ] | f == max<I32> ]
 | Num a
 | a.v = 1
 | Num b
 | b.v = 5
 | (printf)[ "%d %d\n" | (less<Num>)[ @a | @b ] | (less<Num>)[ @b | @a ] ]
 | Box<I32> bx
 | bx.v = 10
 | (printf)[ "%d\n" | (bx.bigger)[ 42 ] ]
 | RET [ 0 ]
 \_
