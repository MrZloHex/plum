; an IFACE is not a type
TYPE D:
 | I32 n
 \_
IFACE F<T>: [ @D me ]
 | I32 g: []
 |  | RET [ 1 ]
 |  \_
 \_
I32 main: []
 | F<I32> x
 | RET [ 0 ]
 \_
