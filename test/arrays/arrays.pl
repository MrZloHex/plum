; ARRAYS

!USES <../std/std.pl>

I32 main: []
 | (puts)["ARRAY TEST"]
 | 
 | @U8 arr = (malloc)[ 8 ]
 |
 | U32 c = 0
 | @U8 a = arr
 | LOOP
 |  | IF [ c >= 8 ]
 |  |  | BREAK
 |  |  \_
 |  | 
 |  | @a = c
 |  | a = a + 1
 |  | c = c + 1
 |  \_
 |
 | a = arr
 | c = 0
 | LOOP
 |  | IF [ c >= 8 ]
 |  |  | BREAK
 |  |  \_
 |  | 
 |  | U8 huy = @a
 |  | (print_num)[ huy ]
 |  | (puts)[" qwe"]
 |  | 
 |  | a = a + 1
 |  | c = c + 1
 |  \_
 | 
 | (free)[ arr ]
 | RET [ 0 ]
 \_

; ARRAYS

