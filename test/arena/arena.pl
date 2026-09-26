; lib/arena.pl through reset cycles: memory is reused, the block chain
; never loses a block (each lost one would leak), and an allocation larger
; than a block still gets one of its own.

!USES <../../lib/arena.pl>
!USES <../../extern/stdio.pl>

I32 blocks: [ @Arena a ]
 | I32 n = 0
 | @ArenaBlock b = a.first
 | WHILE [ b != NULL ]
 |  | n += 1
 |  | b = b.next
 |  \_
 | RET [ n ]
 \_

; fill three 64-byte blocks, 16 bytes at a time, and hand back the first
; allocation of the second block: after a reset it must land in the same
; block again, not in a fresh one that replaced it
@ABYSS fill: [ @Arena a ]
 | @ABYSS second_block = NULL
 | I32 i = 0
 | WHILE [ i < 12 ]
 |  | @ABYSS q = (arena_alloc)[ a | 16 ]
 |  | IF [ i == 4 ]
 |  |  | second_block = q
 |  |  \_
 |  | i += 1
 |  \_
 | RET [ second_block ]
 \_

I32 main: []
 | Arena a
 | (arena_init)[ @a | 64 ]
 | @ABYSS p = (fill)[ @a ]
 | (printf)[ "after one fill: %d blocks\n" | (blocks)[ @a ] ]
 |
 | I32 round = 0
 | B1 same = TRUE
 | WHILE [ round < 5 ]
 |  | (arena_reset)[ @a ]
 |  | IF [ (fill)[ @a ] != p ]
 |  |  | same = FALSE
 |  |  \_
 |  | round += 1
 |  \_
 | (printf)[ "after five resets: %d blocks, second block reused: %d\n" | (blocks)[ @a ] | same ]
 |
 | ; bigger than a block: a block of its own, spliced in, nothing dropped
 | (arena_reset)[ @a ]
 | @C1 big = (arena_alloc)[ @a | 200 ] AS @C1
 | big{199} = 'z'
 | (fill)[ @a ]
 | (printf)[ "with a 200-byte block: %d blocks, %c\n" | (blocks)[ @a ] | big{199} ]
 |
 | (arena_destroy)[ @a ]
 | (printf)[ "destroyed: %d blocks\n" | (blocks)[ @a ] ]
 | RET [ 0 ]
 \_
