; a call through a pointer checks its arguments like any other
I32 add: [ I32 a | I32 b ]
 | RET [ a + b ]
 \_

TYPE Pair:
 | I32 a
 | I32 b
 \_

I32 main: []
 | FN I32 [ I32 | I32 ] op = add
 | Pair p
 | RET [ (op)[ p | 3 ] ]
 \_
