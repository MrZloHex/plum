; calling a method the class does not have
TYPE Data:
 | I32 n
 \_

IFACE Ops: [ @Data me ]
 | I32 get: []
 |  | RET [ me.n ]
 |  \_
 \_

CLASS Box: Data IMPL [ Ops ]

I32 main: []
 | Box b
 | RET [ (b.put)[ 1 ] ]
 \_
