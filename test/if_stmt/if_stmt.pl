; TEST OF BRANCHING

I32 main: []
 | @C1 str = "Hello from PLUM!"
 |
 | B1 why_not = TRUE
 | 
 | IF [ TRUE ]
 |  | (puts)[ "outer if" ]
 |  | IF [ why_not ]
 |  |  | (puts)[ "if inner if" ]
 |  |  \
 |  | ELSE
 |  |  | (puts)[ "if inner else" ]
 |  |  \_
 |  \
 | ELSE
 |  | (puts)[ "outer else" ]
 |  | IF [ why_not ]
 |  |  | (puts)[ "else inner if" ]
 |  |  \
 |  | ELSE
 |  |  | (puts)[ "else inner else" ]
 |  |  \_
 |  \_
 | (puts)[ str ]
 | RET [ 0 ]
 \_


I32 puts:    [ @C1 str ]

