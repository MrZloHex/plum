; Exercises plum/preproc.pl -- nested includes, path resolution relative
; to the including file, and comment/literal skipping.

!USES <../../src/preproc.pl>

I32 main: []
 | String src
 | @ABYSS f = (fopen)[ "sample.txt" | "r" ]
 | IF [ f == 0 ]
 |  | (puts)[ "cannot open sample.txt" ]
 |  | RET [ 1 ]
 |  \_
 | (src.init_file)[ f ]
 | (fclose)[ f ]
 |
 | (printf)[ "before: %d bytes\n" | src.size ]
 |
 | I32 rc = (preprocess)[ @src | "sample.txt" ]
 | (printf)[ "preprocess rc=%d\n" | rc ]
 | (printf)[ "after: %d bytes\n---\n%s---\n" | src.size | src.data ]
 |
 | (src.deinit)[]
 | RET [ 0 ]
 \_
