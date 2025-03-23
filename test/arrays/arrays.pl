; ARRAYS

@ABYSS malloc: [ U64 size ]
ABYSS  free:   [ @ABYSS ptr ]

I32 puts: [ @C1 str ]

I32 main: []
 | @C1 str
 | str = "ARRAYS TEST"
 | (puts)[str]
 | U64 size
 | size = 8
 | @U8 arr
 | arr = (malloc)[ size ]
 | @U8 el
 | el = arr
 | @el = 8
 | (free)[ arr ]
 | RET [ 0 ]
 \_
