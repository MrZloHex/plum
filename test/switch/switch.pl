; switch.pl -- SWITCH: CASE lists, ELSE, no fallthrough, BREAK and CONTINUE reach the loop
I32 printf: [ @C1 fmt | ... ]

TYPE Color: ENUM
 | RED
 | GREEN = 5
 | BLUE
 \_

@C1 name: [ Color c ]
 | SWITCH [ c ]
 | CASE [ RED ]
 |  | RET [ "red" ]
 | CASE [ GREEN | BLUE ]
 |  | RET [ "green-or-blue" ]
 |  \_
 | RET [ "?" ]
 \_

I32 kind: [ C1 ch ]
 | SWITCH [ ch ]
 | CASE [ '+' | '-' ]
 |  | RET [ 1 ]
 | CASE [ '0' ]
 |  | RET [ 2 ]
 | ELSE
 |  | RET [ 0 ]
 |  \_
 \_

I32 main: []
 | (printf)[ "%s %s %s\n" | (name)[ RED ] | (name)[ BLUE ] | (name)[ 7 AS Color ] ]
 | (printf)[ "%d %d %d %d\n" | (kind)[ '+' ] | (kind)[ '-' ] | (kind)[ '0' ] | (kind)[ 'x' ] ]
 | I32 hits = 0
 | FOR [ I32 i = 0 | i < 10 | i += 1 ]
 |  | SWITCH [ i ]
 |  | CASE [ 3 ]
 |  |  | CONTINUE
 |  | CASE [ 8 ]
 |  |  | BREAK
 |  | CASE [ -1 | ~5 ]
 |  |  | hits += 100
 |  | ELSE
 |  |  | hits += 1
 |  |  \_
 |  \_
 | (printf)[ "hits %d\n" | hits ]
 | RET [ 0 ]
 \_
