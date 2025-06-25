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
 | (printf) [ "GOT %u ARGS\n" | argc ]
 | I32 arg_counter = 0
 | LOOP
 |  | IF [ arg_counter == argc ]
 |  |  | BREAK
 |  |  \_
 |  |
 |  | @C1 s = ?(argv + arg_counter)
 |  | (printf) [ "ARG %u is %s\n" | arg_counter | s ]
 |  | 
 |  | arg_counter = arg_counter + 1
 |  \_
 | RET [ 0 ]
 \_

I32 printf: [ @C1 fmt | ... ]
