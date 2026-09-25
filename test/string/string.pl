; Exercises plum/string.pl -- the PLUM counterpart of inc/dynstr.h

!USES <../../lib/string.pl>

ABYSS show: [ @C1 tag | @String s ]
 | (printf)[ "%-12s size=%d cap=%d `%s`\n" | tag | s.size | s.cap | s.data ]
 | RET
 \_

I32 main: []
 | String s
 |
 | (str_init_cstr)[ @s | "hello" ]
 | (show)[ "init_cstr" | @s ]
 |
 | (str_append_str)[ @s | ", world" ]
 | (show)[ "append_str" | @s ]
 |
 | (str_append)[ @s | '!' ]
 | (show)[ "append char" | @s ]
 |
 | ; insert at the front, and in the middle
 | (str_insert_str)[ @s | 0 | ">> " ]
 | (show)[ "insert head" | @s ]
 |
 | (str_insert_str)[ @s | 8 | "BIG " ]
 | (show)[ "insert mid" | @s ]
 |
 | ; and take it back out
 | (str_remove_range)[ @s | 8 | 4 ]
 | (show)[ "remove" | @s ]
 |
 | (str_remove_range)[ @s | 0 | 3 ]
 | (show)[ "remove head" | @s ]
 |
 | ; substring is caller-owned
 | @C1 sub = (str_substr)[ @s | 7 | 5 ]
 | (printf)[ "substr(7,5)=`%s`\n" | sub ]
 | (free)[ sub AS @ABYSS ]
 |
 | ; clamped: asking past the end yields what is there
 | @C1 tail = (str_substr)[ @s | 7 | 999 ]
 | (printf)[ "substr clamped=`%s`\n" | tail ]
 | (free)[ tail AS @ABYSS ]
 |
 | ; indexing
 | (printf)[ "get(0)=%c get(4)=%c oob=%d\n" | (str_get)[ @s | 0 ] | (str_get)[ @s | 4 ] | (str_get)[ @s | 999 ] ]
 |
 | ; growth: force several reallocs
 | String g
 | (str_init_cap)[ @g | 0 ]
 | I32 i = 0
 | WHILE [ i < 200 ]
 |  | (str_append)[ @g | 'x' ]
 |  | i += 1
 |  \_
 | (printf)[ "grown size=%d cap=%d first=%c last=%c\n" | g.size | g.cap | (str_get)[ @g | 0 ] | (str_get)[ @g | 199 ] ]
 |
 | ; read a file, the way the compiler reads its input
 | String f
 | @ABYSS fh = (fopen)[ "string.pl" | "r" ]
 | IF [ fh == 0 ]
 |  | (puts)[ "fopen failed" ]
 |  | RET [ 1 ]
 |  \_
 | (str_init_file)[ @f | fh ]
 | (fclose)[ fh ]
 | @C1 head = (str_substr)[ @f | 0 | 14 ]
 | (printf)[ "file size=%d head=`%s`\n" | f.size | head ]
 | (free)[ head AS @ABYSS ]
 |
 | (str_deinit)[ @f ]
 | (str_deinit)[ @g ]
 | (str_deinit)[ @s ]
 | RET [ 0 ]
 \_
