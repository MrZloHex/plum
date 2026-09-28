; writing through a pointer to CONST
I32 main: []
 | I32 n = 1
 | @CONST I32 p = @n
 | ?p = 2
 | RET [ 0 ]
 \_
