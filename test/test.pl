; SOME COMMENT

U32 foo: [ U32 a | U32 b | U8 unused ]
 | U32 res
 | res = a + b
 | RET [ res ]
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
