; TEST OF CALLING EXTERNAL FUNCTION FROM C

ABYSS println: [ @C1 str ]
 | C1 newline
 | newline = '\n'
 | (puts)[str]
 | (purchar)[newline]
 | RET []
 \_

I32 main: []
 | @C1 str
 | str = "Hello from PLUM!"
 | (println)[ str ]
 | RET [ 0 ]
 \_

I32 puts:    [ @C1 str ]

I32 putchar: [ I32 char ]
