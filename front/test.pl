; SOME COMMENT

U32 foo: [ U32 a | U32 b ]
 | U32 res = a + b
 | RET [ res ]
 \_

I32 main: []
 | U32 a = 34
 | U32 b = 69
 | U32 res = (foo)[ a | b ]
 | RET [ 0 ]
 \_
