; cstdio.pl

I32 puts:    [ @C1 str ]
I32 putchar: [ I32 char ]
I32 printf:  [ @C1 fmt | ... ]

@ABYSS fopen:  [ @C1 path | @C1 mode ]
I32    fclose: [ @ABYSS f ]
U64    fread:  [ @ABYSS buf | U64 sz | U64 n | @ABYSS f ]
I32    fseek:  [ @ABYSS f | I64 off | I32 whence ]
I64    ftell:  [ @ABYSS f ]

I32 snprintf: [ @C1 buf | U64 n | @C1 fmt | ... ]
I32 fprintf:  [ @ABYSS f | @C1 fmt | ... ]
I32 fflush:   [ @ABYSS f ]
