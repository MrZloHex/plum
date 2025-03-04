; io.pl

I32 putchar: [ I32 char ]

I32 puts: [ @C1 str ]

ABYSS println: [ @C1 str ]
 | I32 newline
 | newline = '\n'
 | (puts)[str]
 | (putchar)[newline]
 | RET []
 \_

