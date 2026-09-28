; T must IMPL Ord<T>, and a plain struct IMPLs nothing
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
B1 less<T>: [ @T a | @T b ] REQ [ T IMPL Ord<T> ]
 | RET [ (a.cmp)[ b ] < 0 ]
 \_
TYPE P: STRUCT
 | I32 v
 \_
I32 main: []
 | P a
 | RET [ (less<P>)[ @a | @a ] AS I32 ]
 \_
