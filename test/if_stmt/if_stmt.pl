; TEST OF CALLING EXTERNAL FUNCTION FROM C

ABYSS println: [ @C1 str ]
 | I32 newline
 | newline = '\n'
 | (puts)[str]
 | (putchar)[newline]
 | RET []
 \_

I32 main: []
 | @C1 str
 | str = "Hello from PLUM!"
 | @C1 hello
 | hello = "if working"
 | B1 why
 | why = FALSE
 | IF [ why ]
 |  |  (println) [ hello ]
 |  \_
 | (println)[ str ]
 | RET [ 0 ]
 \_


I32 puts:    [ @C1 str ]

I32 putchar: [ I32 char ]

