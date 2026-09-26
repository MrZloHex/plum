; a CLASS cannot get the same method from two interfaces
TYPE D:
 | I32 n
 \_
IFACE F: [ @D me ]
 | I32 g: []
 |  | RET [ 1 ]
 |  \_
 \_
CLASS C: D IMPL [ F | F ]
I32 main: []
 | RET [ 0 ]
 \_
