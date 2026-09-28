; the REQ gives T Ord's methods and no fields
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
 | RET [ a.secret < b.v ]
 \_
I32 main: []
 | Num a
 | RET [ (less<Num>)[ @a | @a ] AS I32 ]
 \_
