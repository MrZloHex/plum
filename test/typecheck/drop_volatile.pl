; a pointer to VOLATILE cannot quietly become a plain one
I32 main: []
 | @VOLATILE U32 r = 0x5000 AS @VOLATILE U32
 | @U32 p = r
 | RET [ 0 ]
 \_
