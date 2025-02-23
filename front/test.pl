; COMMENT

U32 add: [ U32 a | U32 b ]
 | U32 res = a + b
 | RET [res]
 \_


I32 main: [ USIZE argc | @@C1 argv ]
 | ; ANOTHER COMMENT
 | USIZE size = argc
 | ; TEST ALL TYPES
 | B1 bool
 | C1 char
 | C2 char16
 | C4 widechar
 | F32 float
 | F64 double
 | U8  u8  = 1
 | U16 u16 = 2
 | U32 u32 = 4
 | U64 u64 = 8
 | I8  i8  = u8
 | I16 i16 = u16
 | I32 i32 = u32
 | I64 i64 = u64
 |
 | U32 res = (add)[u16|u32]
 |
 | RET [ 0 ]
 \_
