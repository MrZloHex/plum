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
 | (print_num) [ argc ]
 | @C1 str
 | str = " CLI ARGS TEST"
 | (puts)[ str ]
 |
 | @@C1 args
 | args = argv
 | B1 no_arg
 | I32 arg_counter
 | arg_counter = 1
 | LOOP
 |  | no_arg = arg_counter == argc
 |  | IF [ no_arg ]
 |  |  | BREAK
 |  |  \_
 |  | (print_num)[ arg_counter ]
 |  | arg_counter = arg_counter + 1
 |  | str = " IS ARG"
 |  | (puts) [ str ]
 |  | (print_num) [ args ]
 |  | (puts) [ str ]
 |  \_
 | RET [ 0 ]
 \_


I32 puts:    [ @C1 str ]

I32 putchar: [ I32 char ]
