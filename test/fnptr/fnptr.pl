; Function pointers: variables, parameters, fields, arrays, aliases,
; returning them, generics over them, and calling C through one.

!USES <../../extern/stdio.pl>
!USES <../../extern/stdlib.pl>

I32 add: [ I32 a | I32 b ]
 | RET [ a + b ]
 \_

I32 mul: [ I32 a | I32 b ]
 | RET [ a * b ]
 \_

I32 sub: [ I32 a | I32 b ]
 | RET [ a - b ]
 \_

TYPE BinOp: FN I32 [ I32 | I32 ]

; a pointer as a parameter
I32 fold: [ @I32 xs | I32 n | I32 init | BinOp f ]
 | I32 acc = init
 | I32 i = 0
 | WHILE [ i < n ]
 |  | acc = (f)[ acc | xs{i} ]
 |  | i += 1
 |  \_
 | RET [ acc ]
 \_

; and as a result
BinOp pick: [ C1 op ]
 | IF [ op == '+' ]
 |  | RET [ add ]
 | ELIF [ op == '*' ]
 |  | RET [ mul ]
 |  \_
 | RET [ NULL ]
 \_

; a hand-made vtable
TYPE Shape:
 | I32                     w
 | I32                     h
 | FN I32 [ @Shape ]       area
 | FN ABYSS [ @Shape | I32 ] grow
 \_

I32 rect_area: [ @Shape s ]
 | RET [ s.w * s.h ]
 \_

I32 tri_area: [ @Shape s ]
 | RET [ s.w * s.h / 2 ]
 \_

ABYSS scale: [ @Shape s | I32 k ]
 | s.w *= k
 | s.h *= k
 \_

; qsort takes a C comparator
ABYSS qsort: [ @ABYSS base | U64 n | U64 size | FN I32 [ @ABYSS | @ABYSS ] cmp ]

I32 by_value: [ @ABYSS a | @ABYSS b ]
 | RET [ ?(a AS @I32) - ?(b AS @I32) ]
 \_

; generic over the function type
TYPE Callback<T>:
 | FN ABYSS [ T ] fn
 | I32            calls
 \_

ABYSS say: [ @C1 s ]
 | (printf)[ "  say %s\n" | s ]
 \_

FN I32 [ I32 | I32 ] GLOBAL_OP = sub

I32 main: []
 | FN I32 [ I32 | I32 ] op = add
 | (printf)[ "op(2, 3) = %d\n" | (op)[ 2 | 3 ] ]
 | op = mul
 | (printf)[ "op(2, 3) = %d\n" | (op)[ 2 | 3 ] ]
 | (printf)[ "global: %d\n" | (GLOBAL_OP)[ 10 | 4 ] ]
 |
 | I32 xs{5}
 | I32 i = 0
 | WHILE [ i < 5 ]
 |  | xs{i} = i + 1
 |  | i += 1
 |  \_
 | (printf)[ "fold +: %d, fold *: %d\n" | (fold)[ xs | 5 | 0 | add ] | (fold)[ xs | 5 | 1 | (pick)[ '*' ] ] ]
 | (printf)[ "call a returned pointer: %d\n" | ((pick)[ '+' ])[ 40 | 2 ] ]
 | IF [ (pick)[ '?' ] == NULL && !(pick)[ '?' ] && (pick)[ '+' ] ]
 |  | (printf)[ "NULL compares\n" ]
 |  \_
 |
 | BinOp table{3}
 | table{0} = add
 | table{1} = sub
 | table{2} = mul
 | I32 k = 0
 | WHILE [ k < 3 ]
 |  | (printf)[ "table{%d}(6, 3) = %d\n" | k | (table{k})[ 6 | 3 ] ]
 |  | k += 1
 |  \_
 |
 | Shape r
 | r.w = 4
 | r.h = 5
 | r.area = rect_area
 | r.grow = scale
 | Shape t = r
 | t.area = tri_area
 | (r.grow)[ @r | 2 ]
 | (printf)[ "rect %d, tri %d\n" | (r.area)[ @r ] | (t.area)[ @t ] ]
 | @Shape ps = @t
 | (printf)[ "through a pointer: %d\n" | (ps.area)[ ps ] ]
 |
 | I32 nums{6}
 | nums{0} = 42
 | nums{1} = 7
 | nums{2} = 19
 | nums{3} = -3
 | nums{4} = 0
 | nums{5} = 7
 | (qsort)[ nums | 6 | SIZE [ I32 ] | by_value ]
 | (printf)[ "sorted: %d %d %d %d %d %d\n" | nums{0} | nums{1} | nums{2} | nums{3} | nums{4} | nums{5} ]
 |
 | Callback<@C1> cb
 | cb.fn = say
 | (cb.fn)[ "hello" ]
 | RET [ 0 ]
 \_
