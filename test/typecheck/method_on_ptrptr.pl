; a method call steps through one pointer, not two
TYPE D:
 | I32 n
 \_
IFACE F: [ @D me ]
 | I32 g: []
 |  | RET [ 1 ]
 |  \_
 \_
CLASS C: D IMPL [ F ]
I32 main: []
 | C c
 | @C p = @c
 | @@C pp = @p
 | RET [ (pp.g)[] ]
 \_
