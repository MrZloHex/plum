; errors.pl -- Option and Result in use
;
;   plc --emit=OBJ errors.pl -o errors.o && clang errors.o -o errors

!USES <option.pl>
!USES <result.pl>
!USES <../extern/stdio.pl>
!USES <../extern/string.pl>

; A decimal number, or why the text is not one.
Result<I64 | @C1> parse_int: [ @C1 s ]
 | I32 i = 0
 | B1 neg = s{0} == '-'
 | IF [ neg ]
 |  | i = 1
 |  \_
 | IF [ s{i} == '\0' ]
 |  | RET [ (Result<I64 | @C1>.err)[ "no digits" ] ]
 |  \_
 |
 | I64 n = 0
 | WHILE [ s{i} != '\0' ]
 |  | IF [ s{i} < '0' || s{i} > '9' ]
 |  |  | RET [ (Result<I64 | @C1>.err)[ "not a digit" ] ]
 |  |  \_
 |  | n = n * 10 + (s{i} AS I64) - 48
 |  | i += 1
 |  \_
 | IF [ neg ]
 |  | n = -n
 |  \_
 | RET [ (Result<I64 | @C1>.ok)[ n ] ]
 \_

; Where `name` is in the table -- if it is. Not finding it is no error.
Option<I32> index_of: [ @@C1 names | I32 count | @C1 name ]
 | I32 i = 0
 | WHILE [ i < count ]
 |  | IF [ (strcmp)[ names{i} | name ] == 0 ]
 |  |  | RET [ (Option<I32>.some)[ i ] ]
 |  |  \_
 |  | i += 1
 |  \_
 | RET [ (Option<I32>.none)[] ]
 \_

; The sum of every number, or the first error: what Rust's `?` does, by hand.
Result<I64 | @C1> sum_of: [ @@C1 texts | I32 count ]
 | I64 total = 0
 | I32 i = 0
 | WHILE [ i < count ]
 |  | Result<I64 | @C1> x = (parse_int)[ texts{i} ]
 |  | IF [ (x.is_err)[] ]
 |  |  | RET [ x ]
 |  |  \_
 |  | total += x.as.value
 |  | i += 1
 |  \_
 | RET [ (Result<I64 | @C1>.ok)[ total ] ]
 \_

ABYSS show_parse: [ @C1 text ]
 | Result<I64 | @C1> n = (parse_int)[ text ]
 | IF [ (n.is_ok)[] ]
 |  | (printf)[ "parse \"%s\" -> %ld\n" | text | n.as.value ]
 | ELSE
 |  | (printf)[ "parse \"%s\" -> error: %s\n" | text | n.as.error ]
 |  \_
 \_

I32 main: []
 | ; --- Result: a value, or why not
 | (show_parse)[ "42" ]
 | (show_parse)[ "-17" ]
 | (show_parse)[ "4x2" ]
 | (show_parse)[ "" ]
 | (printf)[ "\"oops\" or 0 -> %ld\n" | (((parse_int)[ "oops" ]).unwrap_or)[ 0 ] ]
 |
 | ; --- Option: a value, or nothing
 | @C1 names{3}
 | names{0} = "ada"
 | names{1} = "grace"
 | names{2} = "linus"
 | Option<I32> g = (index_of)[ names | 3 | "grace" ]
 | (printf)[ "grace is at %d; is_some=%d\n" | (g.unwrap)[] | (g.is_some)[] ]
 | (printf)[ "ken is at %d\n" | (((index_of)[ names | 3 | "ken" ]).unwrap_or)[ -1 ] ]
 |
 | ; --- an error passed up from inside a loop
 | @C1 good{3}
 | good{0} = "1"
 | good{1} = "20"
 | good{2} = "300"
 | (printf)[ "sum of 1 20 300 -> %ld\n" | (((sum_of)[ good | 3 ]).unwrap)[] ]
 | @C1 bad{3}
 | bad{0} = "1"
 | bad{1} = "two"
 | bad{2} = "3"
 | Result<I64 | @C1> s = (sum_of)[ bad | 3 ]
 | (printf)[ "sum of 1 two 3 -> ok=%d, error: %s\n" | (s.is_ok)[] | s.as.error ]
 |
 | (printf)[ "Option<I32> is %lu bytes, Result<I64 | @C1> %lu\n" | SIZE [ Option<I32> ] | SIZE [ Result<I64 | @C1> ] ]
 |
 | ; --- and what happens when the check is skipped
 | (((index_of)[ names | 3 | "ken" ]).expect)[ "ken must be in the table" ]
 | (puts)[ "not reached" ]
 | RET [ 0 ]
 \_
