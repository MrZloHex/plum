; map.pl -- the PLUM counterpart of inc/dynmap.h
;
; dynmap.h takes the key type, value type, hash and equality as macro
; parameters. Every live instantiation uses @C1 keys with djb2 hashing and
; strcmp, so those are baked in here and no function pointers are needed.
;
; map_get keeps dynmap's return convention: 1 on hit, 0 on miss. That is
; the opposite of the 0-on-success used elsewhere, and it is the bug that
; sat in the old codegen for a year -- it is preserved to stay 1:1, so
; check it carefully at every call site.

!USES <../extern/stdlib.pl>
!USES <../extern/string.pl>

TYPE MapEntry: STRUCT
 | @C1       key
 | @ABYSS    value
 | @MapEntry next
 \_

TYPE Map: STRUCT
 | @@MapEntry buckets
 | U64        nbuckets
 | U64        count
 \_

; djb2, matching str_hash in src/meta.c
U64 map_hash: [ @C1 key ]
 | U64 h = 5381
 | @C1 p = key
 | WHILE [ ?(p) != 0 ]
 |  | h = ((h << 5) + h) + (?(p) AS U64)
 |  | p = p + 1
 |  \_
 | RET [ h ]
 \_

I32 map_init: [ @Map m | U64 nbuckets ]
 | m.buckets  = 0
 | m.nbuckets = 0
 | m.count    = 0
 |
 | IF [ nbuckets == 0 ]
 |  | nbuckets = 64
 |  \_
 |
 | @@MapEntry b = (malloc)[ nbuckets * 8 ] AS @@MapEntry
 | IF [ b == 0 ]
 |  | RET [ -1 ]
 |  \_
 |
 | U64 i = 0
 | WHILE [ i < nbuckets ]
 |  | ?(b + i) = 0
 |  | i = i + 1
 |  \_
 |
 | m.buckets  = b
 | m.nbuckets = nbuckets
 | RET [ 0 ]
 \_

ABYSS map_deinit: [ @Map m ]
 | IF [ m.buckets == 0 ]
 |  | RET
 |  \_
 |
 | U64 i = 0
 | WHILE [ i < m.nbuckets ]
 |  | @MapEntry e = ?(m.buckets + i)
 |  | WHILE [ e != 0 ]
 |  |  | @MapEntry nxt = e.next
 |  |  | (free)[ e AS @ABYSS ]
 |  |  | e = nxt
 |  |  \_
 |  | i = i + 1
 |  \_
 |
 | (free)[ m.buckets AS @ABYSS ]
 | m.buckets  = 0
 | m.nbuckets = 0
 | m.count    = 0
 | RET
 \_

U64 map_size: [ @Map m ]
 | RET [ m.count ]
 \_

; Replaces the value when the key is already present. The key pointer is
; stored as given, not copied -- dynmap.h does the same.
I32 map_put: [ @Map m | @C1 key | @ABYSS value ]
 | U64 idx = (map_hash)[ key ] % m.nbuckets
 |
 | @MapEntry e = ?(m.buckets + idx)
 | WHILE [ e != 0 ]
 |  | IF [ (strcmp)[ e.key | key ] == 0 ]
 |  |  | e.value = value
 |  |  | RET [ 0 ]
 |  |  \_
 |  | e = e.next
 |  \_
 |
 | @MapEntry n = (malloc)[ SIZE [ MapEntry ] ] AS @MapEntry
 | IF [ n == 0 ]
 |  | RET [ -1 ]
 |  \_
 | n.key   = key
 | n.value = value
 | n.next  = ?(m.buckets + idx)
 | ?(m.buckets + idx) = n
 | m.count = m.count + 1
 | RET [ 0 ]
 \_

; 1 on hit (value written to out), 0 on miss -- dynmap's convention.
I32 map_get: [ @Map m | @C1 key | @@ABYSS out ]
 | U64 idx = (map_hash)[ key ] % m.nbuckets
 |
 | @MapEntry e = ?(m.buckets + idx)
 | WHILE [ e != 0 ]
 |  | IF [ (strcmp)[ e.key | key ] == 0 ]
 |  |  | ?(out) = e.value
 |  |  | RET [ 1 ]
 |  |  \_
 |  | e = e.next
 |  \_
 | RET [ 0 ]
 \_

I32 map_remove: [ @Map m | @C1 key ]
 | U64 idx = (map_hash)[ key ] % m.nbuckets
 |
 | @MapEntry e    = ?(m.buckets + idx)
 | @MapEntry prev = 0
 | WHILE [ e != 0 ]
 |  | IF [ (strcmp)[ e.key | key ] == 0 ]
 |  |  | IF [ prev == 0 ]
 |  |  |  | ?(m.buckets + idx) = e.next
 |  |  | ELSE
 |  |  |  | prev.next = e.next
 |  |  |  \_
 |  |  | (free)[ e AS @ABYSS ]
 |  |  | m.count = m.count - 1
 |  |  | RET [ 0 ]
 |  |  \_
 |  | prev = e
 |  | e = e.next
 |  \_
 | RET [ -1 ]
 \_
