; SOME COMMENT

U32 foo: [ U32 a | U32 b | U8 unused ]
 | U32 res
 | res = a + b
 | RET [ res ]
 \_

; I32 main: [ USIZE argc | @@C1 argv ]
;  | U32 a = 34
;  | U32 b = 69
;  | U32 res = (foo)[ a | b ]
;  | RET [ 0 ]
;  \_
