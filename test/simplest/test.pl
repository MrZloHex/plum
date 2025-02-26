; SOME COMMENT

U32 foo: [ U32 a | U32 b ]
 | RET [ a + b ]
 \_

I32 main: [ ]
 | U32 a
 | U32 b
 | a = 34
 | b = 35
 | U32 res
 | res = (foo)[ a | b ]
 | RET [ res ]
 \_
