; a function defined twice
I32 f: []
 | RET [ 1 ]
 \_
I32 f: []
 | RET [ 2 ]
 \_
I32 main: []
 | RET [ (f)[] ]
 \_
