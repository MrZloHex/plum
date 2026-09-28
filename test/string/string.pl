; Exercises plum's String class, lib/string.pl -- the counterpart of inc/dynstr.h

!USES <../../lib/string.pl>

ABYSS show: [ @C1 tag | @String s ]
 | (printf)[ "%-12s size=%d cap=%d `%s`\n" | tag | s.size | s.cap | s.data ]
 | RET
 \_

I32 main: []
 | String s
 |
 | (s.init_cstr)[ "hello" ]
 | (show)[ "init_cstr" | @s ]
 |
 | (s.append)[ ", world" ]
 | (show)[ "append_str" | @s ]
 |
 | (s.push)[ '!' ]
 | (show)[ "append char" | @s ]
 |
 | ; insert at the front, and in the middle
 | (s.insert)[ 0 | ">> " ]
 | (show)[ "insert head" | @s ]
 |
 | (s.insert)[ 8 | "BIG " ]
 | (show)[ "insert mid" | @s ]
 |
 | ; and take it back out
 | (s.remove)[ 8 | 4 ]
 | (show)[ "remove" | @s ]
 |
 | (s.remove)[ 0 | 3 ]
 | (show)[ "remove head" | @s ]
 |
 | ; substring is caller-owned
 | @C1 sub = (s.substr)[ 7 | 5 ]
 | (printf)[ "substr(7,5)=`%s`\n" | sub ]
 | (free)[ sub AS @ABYSS ]
 |
 | ; clamped: asking past the end yields what is there
 | @C1 tail = (s.substr)[ 7 | 999 ]
 | (printf)[ "substr clamped=`%s`\n" | tail ]
 | (free)[ tail AS @ABYSS ]
 |
 | ; indexing
 | (printf)[ "get(0)=%c get(4)=%c oob=%d\n" | (s.get)[ 0 ] | (s.get)[ 4 ] | (s.get)[ 999 ] ]
 |
 | ; growth: force several reallocs
 | String g
 | (g.init)[ 0 ]
 | I32 i = 0
 | WHILE [ i < 200 ]
 |  | (g.push)[ 'x' ]
 |  | i += 1
 |  \_
 | (printf)[ "grown size=%d cap=%d first=%c last=%c\n" | g.size | g.cap | (g.get)[ 0 ] | (g.get)[ 199 ] ]
 |
 | ; read a file, the way the compiler reads its input
 | String f
 | @ABYSS fh = (fopen)[ "string.pl" | "r" ]
 | IF [ fh == 0 ]
 |  | (puts)[ "fopen failed" ]
 |  | RET [ 1 ]
 |  \_
 | (f.init_file)[ fh ]
 | (fclose)[ fh ]
 | @C1 head = (f.substr)[ 0 | 14 ]
 | (printf)[ "file size=%d head=`%s`\n" | f.size | head ]
 | (free)[ head AS @ABYSS ]
 |
 | (f.deinit)[]
 | (g.deinit)[]
 | (s.deinit)[]
 | RET [ 0 ]
 \_
