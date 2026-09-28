; a generic function is only ever called with its type arguments
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
 | RET [ (id)[ 1 ] ]
 \_
