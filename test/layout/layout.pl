; PACKED, ALIGN, OFFSET and STATIC_ASSERT: layouts written down and checked

!USES <../../extern/stdio.pl>

TYPE Header: STRUCT
 + PACKED
 | U32 magic
 | U16 version
 | U8  flags
 | U32 crc
 \_

TYPE Inner: STRUCT
 | U16 a
 | U32 b
 \_

TYPE Outer: STRUCT
 | U8    tag
 | Inner in
 \_

TYPE Block: STRUCT
 + ALIGN 32
 | U8 tag
 \_

TYPE Holder: STRUCT
 | U8    c
 | Block b
 \_

TYPE Bytes: UNION
 | U32 word
 | U8  raw{4}
 \_

STATIC_ASSERT [ SIZE [ Header ] == 11 && OFFSET [ Header.crc ] == 7 ]
STATIC_ASSERT [ OFFSET [ Outer.in.b ] == 8 | "Inner is 4-aligned, and b 4 into it" ]
STATIC_ASSERT [ SIZE [ Block ] == 32 && OFFSET [ Holder.b ] == 32 && SIZE [ Holder ] == 64 ]
STATIC_ASSERT [ OFFSET [ Bytes.raw ] == 0 ]

Header saved

I32 main: []
 | saved.magic = 0x504C554D
 | saved.version = 1
 | saved.flags = 7
 | saved.crc = 0xDEADBEEF
 |
 | ; crc lies straight after flags, at 7, little-endian
 | @U8 raw = @saved AS @U8
 | (printf)[ "%lu %lu | %02x %02x %02x %02x\n" | SIZE [ Header ] | OFFSET [ Header.crc ] | raw{7} AS U32 | raw{8} AS U32 | raw{9} AS U32 | raw{10} AS U32 ]
 | (printf)[ "%x %u\n" | saved.crc | saved.flags AS U32 ]           ; deadbeef 7
 |
 | ; ALIGN holds on the stack too, alone or inside another struct
 | Block blk
 | Holder h
 | (printf)[ "%lu %lu %lu\n" | (@blk AS U64) % 32 | (@(h.b) AS U64) % 32 | OFFSET [ Outer.in.b ] ]   ; 0 0 8
 | RET [ 0 ]
 \_
