; an IFACE written for one struct cannot be implemented over another
TYPE A:
 | I32 x
 \_

TYPE B:
 | I32 y
 \_

IFACE OnA: [ @A me ]
 | I32 get: []
 |  | RET [ me.x ]
 |  \_
 \_

CLASS Wrong: B IMPL [ OnA ]

I32 main: []
 | RET [ 0 ]
 \_
