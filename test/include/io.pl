; io.pl

I32 putchar: [ I32 char ]

I32 puts: [ @C1 str ]

ABYSS println: [ @C1 str ]
 | (puts)[str]
 | (putchar)[ 10 ]
 | RET []
 \_

