; a method body is checked once a CLASS uses its IFACE
TYPE D:
 | I32 n
 \_
IFACE F: [ @D me ]
 | I32 g: []
 |  | RET [ me.nope ]
 |  \_
 \_
CLASS C: D IMPL [ F ]
I32 main: []
 | RET [ 0 ]
 \_
