; std.pl -- the program: exercises chained includes std.pl -> lib.pl -> io.pl

!USES <../std/lib.pl>

I32 main: []
 | (puts)[ "STD TEST" ]
 | @ABYSS p = (malloc)[ 16 ]
 | IF [ p != 0 ]
 |  | (puts)[ "malloc ok" ]
 | ELSE
 |  | (puts)[ "malloc failed" ]
 |  \_
 | (free)[ p ]
 | RET [ 0 ]
 \_
