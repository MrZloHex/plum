
I32 printf: [@C1 fmt | ... ]

I32 main: []
 | (printf)["HUY %d%c" | 2 |'\n' ]
 | RET [ 0 ]
 \_
