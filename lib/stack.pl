; stack.pl -- the PLUM counterpart of inc/dynstack.h
;
; Every live instantiation stores pointers (ASTStack holds @ASTNode), so
; this is a stack of @ABYSS rather than a byte-sized generic. Pointer
; arithmetic on @@ABYSS already steps one slot at a time.

!USES <../extern/stdlib.pl>

TYPE Stack: STRUCT
 | @@ABYSS data
 | U64     len
 | U64     cap
 \_

I32 stack_init: [ @Stack s | U64 cap ]
 | s.data = 0
 | s.len  = 0
 | s.cap  = 0
 |
 | IF [ cap == 0 ]
 |  | cap = 16
 |  \_
 |
 | @@ABYSS d = (malloc)[ cap * 8 ] AS @@ABYSS
 | IF [ d == 0 ]
 |  | RET [ -1 ]
 |  \_
 | s.data = d
 | s.cap  = cap
 | RET [ 0 ]
 \_

ABYSS stack_deinit: [ @Stack s ]
 | IF [ s.data != 0 ]
 |  | (free)[ s.data AS @ABYSS ]
 |  \_
 | s.data = 0
 | s.len  = 0
 | s.cap  = 0
 | RET
 \_

U64 stack_size: [ @Stack s ]
 | RET [ s.len ]
 \_

I32 stack_push: [ @Stack s | @ABYSS p ]
 | IF [ s.len == s.cap ]
 |  | U64 ncap = s.cap
 |  | IF [ ncap == 0 ]
 |  |  | ncap = 16
 |  | ELSE
 |  |  | ncap = ncap * 2
 |  |  \_
 |  | @@ABYSS nd = (realloc)[ s.data AS @ABYSS | ncap * 8 ] AS @@ABYSS
 |  | IF [ nd == 0 ]
 |  |  | RET [ -1 ]
 |  |  \_
 |  | s.data = nd
 |  | s.cap  = ncap
 |  \_
 | ?(s.data + s.len) = p
 | s.len = s.len + 1
 | RET [ 0 ]
 \_

; 0 on success, -1 when empty. The popped pointer goes to `out`.
I32 stack_pop: [ @Stack s | @@ABYSS out ]
 | IF [ s.len == 0 ]
 |  | RET [ -1 ]
 |  \_
 | s.len = s.len - 1
 | ?(out) = ?(s.data + s.len)
 | RET [ 0 ]
 \_

I32 stack_peek: [ @Stack s | @@ABYSS out ]
 | IF [ s.len == 0 ]
 |  | RET [ -1 ]
 |  \_
 | ?(out) = ?(s.data + s.len - 1)
 | RET [ 0 ]
 \_
