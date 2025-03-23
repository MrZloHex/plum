; TEST OF CALLING EXTERNAL FUNCTION FROM C

I32 main: []
 | @C1 str = "Hello from PLUM!"
 | (puts)[ str ]
 | RET [ 0 ]
 \_

I32 puts:    [ @C1 str ]

