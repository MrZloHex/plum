; `...` goes on as one va_list: printf takes none, vprintf does
I32 printf: [ @C1 fmt | ... ]
ABYSS say: [ @C1 fmt | ... ]
 | (printf)[ fmt | ... ]
 \_
I32 main: []
 | RET [ 0 ]
 \_
