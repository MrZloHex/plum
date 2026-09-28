; a parameter named twice
I32 f: [ I32 a | I32 a ]
 | RET [ a ]
 \_
I32 main: []
 | RET [ (f)[ 1 | 2 ] ]
 \_
