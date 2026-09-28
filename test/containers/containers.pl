; Exercises lib/{vector,stack,map,arena}.pl against the behaviour the
; compiler relies on from inc/{dynarray,dynstack,dynmap,arena}.h

!USES <../../lib/vector.pl>
!USES <../../lib/stack.pl>
!USES <../../lib/map.pl>
!USES <../../lib/arena.pl>
!USES <../../extern/stdio.pl>

TYPE Sym: STRUCT
 | @C1 name
 | I32 kind
 | I32 line
 \_

I32 main: []
 | ; ---------------- Vector of structs (Symbols / Scopes) ----------------
 | Vector<Sym> v
 | (v.init)[ 0 ]
 | (printf)[ "vec esz=%d\n" | SIZE [ Sym ] ]
 |
 | I32 i = 0
 | WHILE [ i < 20 ]
 |  | Sym s
 |  | s.name = "sym"
 |  | s.kind = i
 |  | s.line = i * 10
 |  | (v.push)[ s ]
 |  | i += 1
 |  \_
 | (printf)[ "vec len=%d cap=%d\n" | (v.size)[] | v.cap ]
 |
 | @Sym got = (v.at)[ 7 ]
 | (printf)[ "vec[7] kind=%d line=%d name=%s\n" | got.kind | got.line | got.name ]
 |
 | ; remove element 0, everything shifts down
 | (v.remove)[ 0 ]
 | got = (v.at)[ 0 ]
 | (printf)[ "after remove len=%d vec[0].kind=%d\n" | (v.size)[] | got.kind ]
 | (v.deinit)[]
 |
 | ; ---------------- Stack of pointers (ASTStack) ----------------
 | Stack st
 | (stack_init)[ @st | 0 ]
 | @C1 a = "alpha"
 | @C1 b = "beta"
 | @C1 c = "gamma"
 | (stack_push)[ @st | a AS @ABYSS ]
 | (stack_push)[ @st | b AS @ABYSS ]
 | (stack_push)[ @st | c AS @ABYSS ]
 |
 | @ABYSS top = 0
 | (stack_peek)[ @st | @top AS @@ABYSS ]
 | (printf)[ "stack size=%d peek=%s\n" | (stack_size)[ @st ] | top AS @C1 ]
 |
 | WHILE [ (stack_size)[ @st ] > 0 ]
 |  | @ABYSS p = 0
 |  | (stack_pop)[ @st | @p AS @@ABYSS ]
 |  | (printf)[ "  pop %s\n" | p AS @C1 ]
 |  \_
 | (stack_deinit)[ @st ]
 |
 | ; ---------------- Map, @C1 keys (func_decls / types) ----------------
 | Map m
 | (map_init)[ @m | 0 ]
 | (map_put)[ @m | "puts"   | 1 AS @ABYSS ]
 | (map_put)[ @m | "printf" | 2 AS @ABYSS ]
 | (map_put)[ @m | "malloc" | 3 AS @ABYSS ]
 | (printf)[ "map size=%d\n" | (map_size)[ @m ] ]
 |
 | @ABYSS out = 0
 | (printf)[ "get printf hit=%d val=%d\n" | (map_get)[ @m | "printf" | @out AS @@ABYSS ] | out AS U64 ]
 | (printf)[ "get absent hit=%d\n" | (map_get)[ @m | "nope" | @out AS @@ABYSS ] ]
 |
 | ; put replaces rather than duplicating
 | (map_put)[ @m | "printf" | 99 AS @ABYSS ]
 | (map_get)[ @m | "printf" | @out AS @@ABYSS ]
 | (printf)[ "after replace size=%d val=%d\n" | (map_size)[ @m ] | out AS U64 ]
 |
 | (map_remove)[ @m | "puts" ]
 | (printf)[ "after remove size=%d hit=%d\n" | (map_size)[ @m ] | (map_get)[ @m | "puts" | @out AS @@ABYSS ] ]
 | (map_deinit)[ @m ]
 |
 | ; ---------------- Arena (backs the AST) ----------------
 | Arena ar
 | (arena_init)[ @ar | 128 ]
 | @C1 p1 = (arena_alloc)[ @ar | 32 ] AS @C1
 | @C1 p2 = (arena_alloc)[ @ar | 32 ] AS @C1
 | ?(p1) = 'A'
 | ?(p2) = 'B'
 | (printf)[ "arena p1=%c p2=%c distinct=%d aligned=%d\n" | ?(p1) | ?(p2) | p1 != p2 | (p1 AS U64) % 16 == 0 ]
 |
 | ; force a new block: 200 > block_size 128
 | @C1 big = (arena_alloc)[ @ar | 200 ] AS @C1
 | ?(big) = 'C'
 | (printf)[ "arena big=%c\n" | ?(big) ]
 |
 | ; many small allocations across blocks
 | I32 k = 0
 | WHILE [ k < 100 ]
 |  | @C1 q = (arena_alloc)[ @ar | 24 ] AS @C1
 |  | ?(q) = 'z'
 |  | k += 1
 |  \_
 | (puts)[ "arena survived 100 allocs" ]
 | (arena_destroy)[ @ar ]
 |
 | RET [ 0 ]
 \_
