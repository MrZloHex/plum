; SOME COMMENT

ABYSS baz: [ @ABYSS qwe | U8 asd]

ABYSS bar: [ @ABYSS qwe | U8 asd]
 | RET [ ] 
 \_

U8 foo: [ U8 a | U8 b ]
 | RET [ a + b ]
 \_

I32 main: [ ]
 | U8 a = 34
 | U8 b = 35
 | U8 res = (foo)[ a | b ]
 | RET [ res ]
 \_

