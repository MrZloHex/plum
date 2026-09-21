; TEST OF ELIF CHAINS -- a compiler is one long dispatch, so chains must work

I32 puts: [ @C1 str ]

ABYSS classify: [ I32 n ]
 | IF [ n == 0 ]
 |  | (puts)[ "zero" ]
 | ELIF [ n == 1 ]
 |  | (puts)[ "one" ]
 | ELIF [ n == 2 ]
 |  | (puts)[ "two" ]
 | ELIF [ n == 3 ]
 |  | (puts)[ "three" ]
 | ELSE
 |  | (puts)[ "many" ]
 |  \_
 | RET
 \_

ABYSS no_else: [ I32 n ]
 | IF [ n == 0 ]
 |  | (puts)[ "zero" ]
 | ELIF [ n == 1 ]
 |  | (puts)[ "one" ]
 |  \_
 | RET
 \_

I32 main: []
 | (classify)[ 0 ]
 | (classify)[ 1 ]
 | (classify)[ 2 ]
 | (classify)[ 3 ]
 | (classify)[ 9 ]
 | (no_else)[ 1 ]
 | RET [ 0 ]
 \_
