; a call result is not a place
I32 f: []
 | RET [ 1 ]
 \_
I32 main: []
 | (f)[] = 3
 | RET [ 0 ]
 \_
