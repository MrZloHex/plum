; a whole array cannot be assigned; it would only rebind a pointer
I32 main: []
 | I32 a{4}
 | I32 b{4}
 | a = b
 | RET [ 0 ]
 \_
