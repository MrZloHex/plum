; method arguments are checked like any call's, `me` aside
TYPE Data:
 | I32 n
 \_

IFACE Ops: [ @Data me ]
 | ABYSS set: [ I32 v ]
 |  | me.n = v
 |  \_
 \_

CLASS Box: Data IMPL [ Ops ]

I32 main: []
 | Box b
 | Data d
 | (b.set)[ d ]
 | RET [ 0 ]
 \_
