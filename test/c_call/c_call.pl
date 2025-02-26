; TEST OF CALLING EXTERNAL FUNCTION FROM C

I32 main: []
 | U8 qwe
 | qwe = 1
 | @C1 str
 | str = "Hello from PLUM!"
 | (puts)[ str ]
 | RET [ 0 ]
 \_

I32 puts: [ @C1 char ]
