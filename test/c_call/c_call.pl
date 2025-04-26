; TEST OF CALLING EXTERNAL FUNCTION FROM C

ABYSS qwe: []
 | (puts)["QWEQWEQWE"]
 | RET []
 \_

I32 main: []
 | @C1 str = "Hello from PLUM!"
 | (puts)[ str ]
 | (qwe)[ ]
 | RET [ 0 ]
 \_

I32 puts:    [ @C1 str ]

