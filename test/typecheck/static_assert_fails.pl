; a STATIC_ASSERT that does not hold, with its message
TYPE P: STRUCT
 + PACKED
 | U8  a
 | U32 b
 \_
STATIC_ASSERT [ OFFSET [ P.b ] == 4 | "b must be 4-aligned" ]
I32 main: []
 | RET [ 0 ]
 \_
