; cstdlib.pl

@ABYSS malloc:  [ U64 size ]
@ABYSS realloc: [ @ABYSS ptr | U64 size ]
ABYSS  free:    [ @ABYSS ptr ]

ABYSS exit: [ I32 code ]

I64 strtoll: [ @C1 s | @@C1 end | I32 base ]
U64 strtoull: [ @C1 s | @@C1 end | I32 base ]
I32 atoi:    [ @C1 s ]
F64 atof:    [ @C1 s ]
