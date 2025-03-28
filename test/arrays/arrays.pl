; ARRAYS

!USES <../std/std.pl>

I32 main: []
 | (puts)["ARRAY TEST"]
 | 
 | @U8 arr = (malloc)[ 8 ]
 | U8 el
 | el = 42
 | @arr = 9
 |
 | U32 c = 0
 | LOOP
 |  | IF [ c >= 8 ]
 |  |  | BREAK
 |  |  \_
 |  | 
 |  | U8 huy
 |  | huy = @arr
 |  | (print_num)[ huy ]
 |  | (puts)[" qwe"]
 |  | 
 |  | c = c + 1
 |  \_
 | 
 | (free)[ arr ]
 | RET [ 0 ]
 \_

; ARRAYS

