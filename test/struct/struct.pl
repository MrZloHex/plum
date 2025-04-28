!USES <../std/io.pl>

TYPE Foo:
 | I32 a
 | B1  fla
 \_

TYPE Bar:
 | @C1 str
 | U32 size
 \_

TYPE Struct:
 | Foo a
 | @Bar bar
 | U8 q
 \_

I32 main: []
 | (printf)[ "TEST OF STRUCT%c" | '\n' ]
 |
 | Struct t
 | t.a.a = 32
 | t.a.fla = TRUE
 | t.q = 69
 |
 | RET [ 0 ]
 \_
