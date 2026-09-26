; p - q needs pointers to the same type
I32 main: []
 | @I32 p = NULL
 | @C1 q = NULL
 | I64 d = p - q
 | RET [ 0 ]
 \_
