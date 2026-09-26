; a value-returning function must not fall off its end
I32 f: [ I32 x ]
 | IF [ x ]
 |  | RET [ 1 ]
 |  \_
 \_
I32 main: []
 | RET [ (f)[ 0 ] ]
 \_
