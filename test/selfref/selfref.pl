; The shape the self-hosted compiler actually needs:
; a self-referential tagged union, heap-allocated, walked and dispatched.

I32    printf: [ @C1 fmt | ... ]
@ABYSS malloc: [ U64 size ]
ABYSS  free:   [ @ABYSS ptr ]

TYPE Kind: ENUM
 | K_NUM
 | K_ADD
 \_

TYPE Node: STRUCT
 | I32   kind
 | I32   value
 | @Node left
 | @Node right
 | @Node next
 \_

@Node make_num: [ I32 v ]
 | @Node n = (malloc)[ SIZE [ Node ] ]
 | n.kind  = K_NUM
 | n.value = v
 | n.left  = 0
 | n.right = 0
 | n.next  = 0
 | RET [ n ]
 \_

@Node make_add: [ @Node l | @Node r ]
 | @Node n = (malloc)[ SIZE [ Node ] ]
 | n.kind  = K_ADD
 | n.value = 0
 | n.left  = l
 | n.right = r
 | n.next  = 0
 | RET [ n ]
 \_

; recursive dispatch over the tag -- the compiler is one big version of this
I32 eval: [ @Node n ]
 | IF [ n == 0 ]
 |  | RET [ 0 ]
 |  \_
 | IF [ n.kind == K_NUM ]
 |  | RET [ n.value ]
 | ELIF [ n.kind == K_ADD ]
 |  | RET [ (eval)[ n.left ] + (eval)[ n.right ] ]
 | ELSE
 |  | RET [ -1 ]
 |  \_
 \_

I32 main: []
 | @Node a = (make_num)[ 20 ]
 | @Node b = (make_num)[ 22 ]
 | @Node s = (make_add)[ a | b ]
 | (printf)[ "eval=%d\n" | (eval)[ s ] ]
 |
 | ; linked list through the self-pointer
 | a.next = b
 | I32 count = 0
 | @Node cur = a
 | WHILE [ cur != 0 ]
 |  | count += 1
 |  | cur = cur.next
 |  \_
 | (printf)[ "list length=%d\n" | count ]
 |
 | (free)[ s ]
 | (free)[ b ]
 | (free)[ a ]
 | RET [ 0 ]
 \_
