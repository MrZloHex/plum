!USES <cstdio.pl>

I32 main: [ I32 argc | @@C1 argv ]
 | @C1 str
 | str = "Hello from PLUM!"
 | (puts)[str]
 | B1 is_args
 | is_args = argc > 0
 | IF [ is_args ]
 |  | (puts)[argv]
 |  \_
 | RET [ 0 ]
 \_
