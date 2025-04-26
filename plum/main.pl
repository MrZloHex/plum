!USES <cstdio.pl>
!USES <cunistd.pl>

I32 main: [ I32 argc | @@C1 argv ]
 | @C1 cwd = (get_current_dir_name)[]
 | @C1 str
 | str = "Hello from PLUM!"
 | (puts)[str]
 | RET [ 0 ]
 \_
