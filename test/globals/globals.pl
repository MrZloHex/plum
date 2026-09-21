; GLOBAL VARIABLES -- the C compiler has exactly one (Tracer tracer)

I32 printf: [ @C1 fmt | ... ]

TYPE Tracer: STRUCT
 | I32 level
 | I32 params
 \_

I32    counter = 0
I32    limit   = 3
@C1    label   = "global"
Tracer tracer

ABYSS bump: []
 | counter += 1
 | RET
 \_

I32 main: []
 | tracer.level  = 7
 | tracer.params = 15
 |
 | WHILE [ counter < limit ]
 |  | (bump)[]
 |  \_
 |
 | (printf)[ "%s counter=%d level=%d params=%d\n" | label | counter | tracer.level | tracer.params ]
 | RET [ counter ]
 \_
