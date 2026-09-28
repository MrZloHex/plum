; PACKED and ALIGN on one type
TYPE P: STRUCT
 + PACKED
 + ALIGN 8
 | U8 a
 \_
I32 main: []
 | RET [ 0 ]
 \_
