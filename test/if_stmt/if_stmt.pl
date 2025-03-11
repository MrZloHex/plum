; TEST OF BRANCHING

I32 main: []
 | @C1 str
 | str = "Hello from PLUM!"
 |
 | @C1 hello
 | B1 why
 | B1 why_not
 | why = TRUE
 | why_not = TRUE
 | 
 | IF [ why ]
 |  | hello = "if working"
 |  | (puts)[ hello ]
 |  | IF [ why_not ]
 |  |  | hello = "qqq inner if"
 |  |  | (puts)[ hello ]
 |  |  \
 |  | ELSE
 |  |  | hello = "qqq inner else"
 |  |  | (puts)[ hello ]
 |  |  \_
 |  \
 | ELSE
 |  | hello = "else working"
 |  | (puts)[ hello ]
 |  | IF [ why_not ]
 |  |  | hello = "inner if"
 |  |  | (puts)[ hello ]
 |  |  \
 |  | ELSE
 |  |  | hello = "inner else"
 |  |  | (puts)[ hello ]
 |  |  \_
 |  \_
 | (puts)[ str ]
 | RET [ 0 ]
 \_


I32 puts:    [ @C1 str ]

