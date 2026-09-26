; only a function pointer can be called
I32 add: [ I32 a | I32 b ]
 | RET [ a + b ]
 \_

I32 main: []
 | RET [ ((add)[ 1 | 2 ])[ 3 ] ]
 \_
