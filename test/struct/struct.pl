!USES <../std/io.pl>

TYPE struct:
 | I32 a
 | B1  flag
 \_

I32 main: []
 | (printf)[ "TEST OF STRUCT%c" | '\n' ]
 | 
 | RET [ 0 ]
 \_
