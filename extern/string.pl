; cstring.pl

@ABYSS memcpy:  [ @ABYSS dst | @ABYSS src | U64 n ]
@ABYSS memmove: [ @ABYSS dst | @ABYSS src | U64 n ]
U64    strlen:  [ @C1 s ]
I32    strcmp:  [ @C1 a | @C1 b ]
I32    strncmp: [ @C1 a | @C1 b | U64 n ]
@C1    strdup:  [ @C1 s ]
@C1    strndup: [ @C1 s | U64 n ]
@C1    strrchr: [ @C1 s | I32 c ]

@ABYSS memset: [ @ABYSS s | I32 c | U64 n ]
