; OFFSET names a field the struct does not have
TYPE P: STRUCT
 | I32 a
 \_
I32 main: []
 | U64 o = OFFSET [ P.b ]
 | RET [ 0 ]
 \_
