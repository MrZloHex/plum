; OFFSET goes through fields, not through pointers
TYPE Q: STRUCT
 | I32 x
 \_
TYPE P: STRUCT
 | @Q q
 \_
I32 main: []
 | U64 o = OFFSET [ P.q.x ]
 | RET [ 0 ]
 \_
