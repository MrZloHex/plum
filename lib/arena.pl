; arena.pl -- the PLUM counterpart of inc/arena.h
;
; Bump allocator over a list of blocks; nothing is freed individually,
; arena_destroy drops the lot. This is what backs the AST.
;
; The C version hangs the payload off a flexible array member; PLUM has
; none, so each block carries a separately allocated buffer instead.

!USES <../extern/stdlib.pl>

TYPE ArenaBlock: STRUCT
 | U64         used
 | U64         size
 | @C1         data
 | @ArenaBlock next
 \_

TYPE Arena: STRUCT
 | @ArenaBlock first
 | @ArenaBlock current
 | U64         block_size
 \_

ABYSS arena_init: [ @Arena a | U64 block_size ]
 | a.first   = 0
 | a.current = 0
 | IF [ block_size == 0 ]
 |  | block_size = 4096
 |  \_
 | a.block_size = block_size
 | RET
 \_

@ArenaBlock arena_new_block: [ U64 size ]
 | @ArenaBlock b = (malloc)[ SIZE [ ArenaBlock ] ] AS @ArenaBlock
 | IF [ b == 0 ]
 |  | RET [ 0 ]
 |  \_
 | @C1 d = (malloc)[ size ] AS @C1
 | IF [ d == 0 ]
 |  | (free)[ b AS @ABYSS ]
 |  | RET [ 0 ]
 |  \_
 | b.used = 0
 | b.size = size
 | b.data = d
 | b.next = 0
 | RET [ b ]
 \_

@ABYSS arena_alloc: [ @Arena a | U64 size ]
 | U64 align = 16
 | U64 used  = 0
 | IF [ a.current != 0 ]
 |  | used = a.current.used
 |  \_
 | U64 offset = (align - (used % align)) % align
 |
 | B1 need_block = FALSE
 | IF [ a.current == 0 ]
 |  | need_block = TRUE
 | ELIF [ used + offset + size > a.current.size ]
 |  | need_block = TRUE
 |  \_
 |
 | IF [ need_block ]
 |  | ; after arena_reset the blocks past current are empty: reuse the
 |  | ; next one when it fits, and never drop the chain behind it
 |  | @ArenaBlock nb = 0
 |  | IF [ a.current != 0 && a.current.next != 0 ]
 |  |  | IF [ size <= a.current.next.size ]
 |  |  |  | nb = a.current.next
 |  |  |  | nb.used = 0
 |  |  |  \_
 |  |  \_
 |  | IF [ nb == 0 ]
 |  |  | U64 bs = a.block_size
 |  |  | IF [ size > bs ]
 |  |  |  | bs = size
 |  |  |  \_
 |  |  | nb = (arena_new_block)[ bs ]
 |  |  | IF [ nb == 0 ]
 |  |  |  | RET [ 0 ]
 |  |  |  \_
 |  |  | IF [ a.first == 0 ]
 |  |  |  | a.first = nb
 |  |  | ELSE
 |  |  |  | nb.next = a.current.next
 |  |  |  | a.current.next = nb
 |  |  |  \_
 |  |  \_
 |  | a.current = nb
 |  | offset = 0
 |  \_
 |
 | @C1 p = a.current.data + a.current.used + offset
 | a.current.used = a.current.used + offset + size
 | RET [ p AS @ABYSS ]
 \_

; Keep the blocks, forget their contents.
ABYSS arena_reset: [ @Arena a ]
 | @ArenaBlock b = a.first
 | WHILE [ b != 0 ]
 |  | b.used = 0
 |  | b = b.next
 |  \_
 | a.current = a.first
 | RET
 \_

ABYSS arena_destroy: [ @Arena a ]
 | @ArenaBlock b = a.first
 | WHILE [ b != 0 ]
 |  | @ArenaBlock nxt = b.next
 |  | (free)[ b.data AS @ABYSS ]
 |  | (free)[ b AS @ABYSS ]
 |  | b = nxt
 |  \_
 | a.first   = 0
 | a.current = 0
 | RET
 \_
