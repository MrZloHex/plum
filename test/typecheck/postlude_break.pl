; BREAK from a POSTLUDE would jump out of the leaving itself
I32 main: []
 | FOR [ I32 i = 0 | i < 3 | i += 1 ]
 |  | POSTLUDE BREAK
 |  \_
 | RET [ 0 ]
 \_
