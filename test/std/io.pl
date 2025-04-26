; io.pl

I32 puts:    [ @C1 str ]
I32 putchar: [ I32 char ]

ABYSS print_num: [ I32 n ]
 | I32 num = n
 | IF [ num < 0 ] 
 |  | (putchar) [ '-' ]
 |  | num = 0 - num
 |  \_
 |
 | IF [ num / 10 ]
 |  | I32 over = num / 10
 |  | (print_num) [ over ]
 |  \_
 | 
 | I32 rem = (num % 10) + '0'
 | (putchar) [ rem ]
 | RET []
 \_

 ; io.pl
