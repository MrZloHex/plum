; @ABYSS cannot be indexed
!USES <../../extern/stdlib.pl>
I32 main: []
 | @ABYSS p = (malloc)[ 8 ]
 | RET [ p{1} ]
 \_
