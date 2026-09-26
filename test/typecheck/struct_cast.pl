; AS does not convert structs
TYPE D:
 | I32 n
 \_
I32 main: []
 | D d
 | I32 x = d AS I32
 | RET [ 0 ]
 \_
