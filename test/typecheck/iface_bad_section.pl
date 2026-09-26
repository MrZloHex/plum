; sections are PUBLIC or PRIVATE
TYPE D:
 | I32 n
 \_
IFACE F: [ @D me ]
 + SECRET:
 | I32 g: []
 |  | RET [ 1 ]
 |  \_
 \_
I32 main: []
 | RET [ 0 ]
 \_
