; CLI ARGS

ABYSS print_num: [ I32 n ]
 | I32 num
 | num = n
 | 
 | B1 neg
 | neg = num < 0
 | IF [ neg ] 
 |  | C1 minus
 |  | minus = '-'
 |  | (putchar) [ minus ]
 |  | num = 0 - num
 |  \_
 |
 | I32 over
 | over = num / 10
 | IF [ over ]
 |  | (print_num) [ over ]
 |  \_
 | 
 | I32 rem
 | rem = (num % 10) + '0'
 | (putchar) [ rem ]
 | RET []
 \_


I32 main: [ I32 argc | @@C1 argv ]
 | 
 | (print_num) [ argc ]
 | @C1 str
 | str = " CLI ARGS TEST"
 | (puts)[ str ]
 |
 | @@C1 a = argv
 | I32 arg_counter = 0
 | LOOP
 |  | IF [ arg_counter == argc ]
 |  |  | BREAK
 |  |  \_
 |  |
 |  | (print_num)[ arg_counter ]
 |  | (puts) [ " IS ARG " ]
 |  | @C1 s = @a
 |  | (puts) [ s ]
 |  | 
 |  | a = a + 1
 |  | arg_counter = arg_counter + 1
 |  \_
 | RET [ 0 ]
 \_


I32 puts:    [ @C1 str ]

I32 putchar: [ I32 char ]
