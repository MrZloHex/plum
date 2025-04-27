; TEST OF CALLING EXTERNAL FUNCTION FROM C

ABYSS qwe_qwe_qwe: []
 | (puts)["QWEQWEQWE"]
 | RET []
 \_

I32 main: []
 | @C1 str = "Hello from PLUM!"
 | (puts)[ str ]
 | (qwe_qwe_qwe)[ ]
 | RET [ 0 ]
 \_

ABYSS asd: []

I32 puts:    [ @C1 str ]

