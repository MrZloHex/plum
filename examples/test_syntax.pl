!USES <stdlib>
!USES <vector>
; struct:
;   - void *
;   - float
;   - bool
;

!DEF TEMP: F32

TYPE data:
 | @ABYSS data
 | TEMP   temperature
 | BOOL   flag
 \_

TYPE String_T:
 | @C1    data
 |  USIZE length
 |  USIZE cap
 \_

IFACE iface_string: [ String_T me ]
 | USIZE get_length: []
 |  | RET [ me.length ]
 |  \_
 | 
 | @C1 get_cstr: []
 |  | @C1 ptr = (malloc)[ me.length ]
 |  | IF [ ptr = NULL ]
 |  |  | RET [ NULL ]
 |  |  \_
 |  | 
 |  | (strncpy)[ptr | me.data | me.length]
 |  | ; @{me.length}ptr = '\0'
 |  | @ptr{me.length} = '\0'
 |  | RET [ ptr ]
 |  \_
 \_

IFACE iface_common: [ String_T me ]
 | ;...
 \_

IFACE iface_common_ext: [ String_T me ]
 - EXTENDS: iface_common
 |
 |
 |
 \_


CLASS String: String_T IMPL [ iface_string | iface_common ]


TYPE vec<T>:
 |
 |
 \_


IFACE vec_iface<T>: [ vec<T> me ] 
 - EXTENDS  :   smth_iface
 - REQUIRE T: [ some_T_iface1 | some_T_iface2 ]
 |
 |
 \_











I32 main: [ I32 argc | @@C1 argv ]
 | BYTE size: #10
 | QWORD vec = @malloc[ size ]
 | IF vec = #0 THEN
 |  | RET [ #-1 ]
 |  \_
 |  
 | QWORD idx = #0
 | QWORD v: vec
 | LOOP
 |  | @set_element[ v | #0 | #12.32 | #1 ]
 |  | v = v + 8
 |  | IF idx = size THEN
 |  |  | BREAK
 |  |  \_
 |  \_
 | 
 | ->(vec + #5*#8) 
 \_
