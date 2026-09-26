; @ABYSS must be cast before use
!USES <../../extern/stdlib.pl>
I32 main: []
 | @ABYSS p = (malloc)[ 8 ]
 | I32 x = ?p
 | RET [ 0 ]
 \_
