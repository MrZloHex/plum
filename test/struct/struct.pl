;!USES <../std/io.pl>

TYPE Foo: STRUCT
 | I32 a
 | B1  fla
 \_

TYPE Bar: STRUCT
 | @C1 str
 | U32 size
 \_

TYPE Struct: STRUCT
 | Foo a
 | @Bar bar
 | U8 q
 \_

I32 main: []
 | (printf)[ "TEST OF STRUCT\n" ]
 | 
 | Struct t
 | I32 a
 | a = 32
 | t.a.a = 69
 | t.a.fla = TRUE
 | t.q = 69
 | 
 | (printf)[ "A %d t.q %d\n" ]
 | 
 | RET [ 0 ]
 \_
