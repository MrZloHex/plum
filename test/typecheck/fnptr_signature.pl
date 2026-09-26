; a function pointer only takes a function of exactly its signature
I32 add: [ I32 a | I32 b ]
 | RET [ a + b ]
 \_

I32 main: []
 | FN I32 [ I32 ] f = add
 | RET [ 0 ]
 \_
