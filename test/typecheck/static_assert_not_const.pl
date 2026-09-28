; STATIC_ASSERT takes only what the compiler can work out
I32 limit = 3
STATIC_ASSERT [ limit < 5 ]
I32 main: []
 | RET [ 0 ]
 \_
