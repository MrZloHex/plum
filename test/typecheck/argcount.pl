I32 add: [ I32 a | I32 b ]
 | RET [ a + b ]
 \_
I32 main: []
 | RET [ (add)[ 1 ] ]
 \_
