; record.pl -- what goes to flash, byte for byte
;
; PACKED puts the fields back to back, the way they lie in the flash, and
; the STATIC_ASSERTs say what that layout must be -- on every target.
; The union sees the same 15 bytes as a record or as bytes.

!USES <../../extern/stdio.pl>

CONST U32 RECORD_MAGIC = 0x504C554D      ; "PLUM"

TYPE Record: STRUCT
 + PACKED
 | U32 magic
 | U16 version
 | U8  count
 | I32 mean_centi       ; the mean, in hundredths of a degree
 | U32 checksum
 \_

STATIC_ASSERT [ SIZE [ Record ] == 15 ]
STATIC_ASSERT [ OFFSET [ Record.checksum ] == 11 | "the checksum covers the 11 bytes before it" ]

TYPE RecordBytes: UNION
 | Record rec
 | U8     raw{15}
 \_

; a byte sum, turned so that a flash of zeros does not check out
U32 checksum: [ @CONST U8 bytes | USIZE n ]
 | U32 sum = 0
 | USIZE i = 0
 | WHILE [ i < n ]
 |  | sum += bytes{i}
 |  | i += 1
 |  \_
 | RET [ sum ^ 0xA5A5A5A5 ]
 \_

RecordBytes make_record: [ U8 count | F32 mean ]
 | RecordBytes rb
 | rb.rec.magic = RECORD_MAGIC
 | rb.rec.version = 1
 | rb.rec.count = count
 | rb.rec.mean_centi = (mean * 100.0) AS I32
 | rb.rec.checksum = (checksum)[ rb.raw | OFFSET [ Record.checksum ] ]
 | RET [ rb ]
 \_

B1 record_ok: [ @CONST RecordBytes rb ]
 | IF [ rb.rec.magic != RECORD_MAGIC ]
 |  | RET [ FALSE ]
 |  \_
 | RET [ rb.rec.checksum == (checksum)[ rb.raw | OFFSET [ Record.checksum ] ] ]
 \_
