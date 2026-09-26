; a TYPE defined twice
TYPE D:
 | I32 n
 \_
TYPE D:
 | F64 x
 \_
I32 main: []
 | D d
 | RET [ 0 ]
 \_
