; only a function taking `...` has arguments to pass on
I32 vprintf: [ @C1 fmt | @ABYSS ap ]
ABYSS say: [ @C1 fmt ]
 | (vprintf)[ fmt | ... ]
 \_
I32 main: []
 | RET [ 0 ]
 \_
