; TEST OF CALLING EXTERNAL FUNCTION FROM C

I32 main: []
 | I32 H
 | I32 i
 | I32 excl
 | I32 newline
 | H = 'H'
 | i = 'i'
 | excl = '!'
 | newline = '\n'
 | (putchar)[ H        | 1 ]
 | (putchar)[ i        | 1 ]
 | (putchar)[ excl     | 1 ]
 | (putchar)[ newline  | 1 ]
 | RET [ 0 ]
 \_

I32 putchar: [ I32 char ]
