; TEST OF && || ! -- including short-circuit evaluation

I32 printf: [ @C1 fmt | ... ]
I32 puts:   [ @C1 str ]

; returns its argument, and shouts so we can see whether it ran at all
B1 loud: [ B1 v ]
 | (puts)[ "  <evaluated>" ]
 | RET [ v ]
 \_

I32 main: []
 | I32 a = 5
 | I32 b = 2
 |
 | IF [ a > b && b > 0 ]
 |  | (puts)[ "and: both true" ]
 |  \_
 | IF [ a < b || b > 0 ]
 |  | (puts)[ "or: second true" ]
 |  \_
 | IF [ !(a < b) ]
 |  | (puts)[ "not: a is not less than b" ]
 |  \_
 |
 | B1 t = TRUE
 | B1 f = FALSE
 |
 | (puts)[ "short-circuit &&: rhs must NOT run" ]
 | IF [ f && (loud)[ t ] ]
 |  | (puts)[ "  unreachable" ]
 |  \_
 |
 | (puts)[ "short-circuit ||: rhs must NOT run" ]
 | IF [ t || (loud)[ f ] ]
 |  | (puts)[ "  taken" ]
 |  \_
 |
 | (puts)[ "&& with false rhs: rhs MUST run" ]
 | IF [ t && (loud)[ f ] ]
 |  | (puts)[ "  unreachable" ]
 |  \_
 |
 | ; chained, to exercise nesting
 | IF [ a > 0 && b > 0 && a > b ]
 |  | (puts)[ "chain: all three" ]
 |  \_
 |
 | RET [ 0 ]
 \_
