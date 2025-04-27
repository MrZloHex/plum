!USES <cstdio.pl>
!USES <cunistd.pl>

I32 main: [ I32 argc | @@C1 argv ]
 ;| @C1 cwd = (get_current_dir_name)[]
 | @ABYSS stdout = 0
 | (fputs)["QWE qwe"| stdout]
 | (puts)["PLUM PLUM"]
 | RET [ 0 ]
 \_
