; a method cannot be called on a CONST object
TYPE D: STRUCT
 | I32 v
 \_
IFACE Ops: [ @D me ]
 | ABYSS bump: []
 |  | me.v += 1
 |  \_
 \_
CLASS C: D IMPL [ Ops ]
C make: []
 | C x
 | x.v = 0
 | RET [ x ]
 \_
I32 main: []
 | CONST C k = (make)[]
 | (k.bump)[]
 | RET [ 0 ]
 \_
