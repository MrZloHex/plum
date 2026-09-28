; one type parameter, two arguments
TYPE NumData: STRUCT
 | I32 v
 | I32 secret
 \_
IFACE Ord<T>: [ @T me ] REQ [ I32 v ]
 | I32 cmp: [ @T o ]
 |  | RET [ me.v - o.v ]
 |  \_
 \_
T id<T>: [ T a ]
 | RET [ a ]
 \_
I32 main: []
 | RET [ (id<I32 | I32>)[ 1 ] ]
 \_
