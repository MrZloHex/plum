; vector.pl -- Vector<T>, a growable array of T
;
; The typed successor of vec.pl: elements go in and come out as T, so there
; is no element size to pass and no cast on the way out.
;
;   Vector<CGSym> syms
;   (syms.init)[ 16 ]
;   (syms.push)[ sym ]
;   @CGSym s = (syms.at)[ 0 ]
;
; A pointer from `at` points into the vector's own storage, so it is valid
; only until the next push, which may move everything.

!USES <../extern/stdlib.pl>
!USES <../extern/string.pl>
!USES <../extern/stdio.pl>

TYPE VectorData<T>:
 | @T    data
 | USIZE len
 | USIZE cap
 \_

IFACE VectorOps<T>: [ @VectorData<T> me ]
 + PUBLIC:
 | ABYSS init: [ USIZE cap ]
 |  | me.data = NULL
 |  | me.len = 0
 |  | me.cap = 0
 |  | IF [ cap == 0 ]
 |  |  | cap = 8
 |  |  \_
 |  | (me.grow)[ cap ]
 |  \_
 |
 | ABYSS deinit: []
 |  | (free)[ me.data AS @ABYSS ]
 |  | me.data = NULL
 |  | me.len = 0
 |  | me.cap = 0
 |  \_
 |
 | USIZE size: []
 |  | RET [ me.len ]
 |  \_
 |
 | B1 empty: []
 |  | RET [ me.len == 0 ]
 |  \_
 |
 | ; the i-th element, in place; no bounds check, as with vec_at
 | @T at: [ USIZE i ]
 |  | RET [ me.data + i ]
 |  \_
 |
 | @T last: []
 |  | RET [ me.data + me.len - 1 ]
 |  \_
 |
 | ABYSS push: [ T v ]
 |  | IF [ me.len == me.cap ]
 |  |  | (me.grow)[ me.cap * 2 ]
 |  |  \_
 |  | me.data{me.len} = v
 |  | me.len += 1
 |  \_
 |
 | ABYSS pop: []
 |  | IF [ me.len > 0 ]
 |  |  | me.len -= 1
 |  |  \_
 |  \_
 |
 | ; FALSE when i is out of range
 | B1 remove: [ USIZE i ]
 |  | IF [ i >= me.len ]
 |  |  | RET [ FALSE ]
 |  |  \_
 |  | USIZE rest = me.len - i - 1
 |  | IF [ rest > 0 ]
 |  |  | (memmove)[ (me.data + i) AS @ABYSS | (me.data + i + 1) AS @ABYSS | rest * SIZE [ T ] ]
 |  |  \_
 |  | me.len -= 1
 |  | RET [ TRUE ]
 |  \_
 |
 | ABYSS clear: []
 |  | me.len = 0
 |  \_
 |
 + PRIVATE:
 | ABYSS grow: [ USIZE cap ]
 |  | IF [ cap < 8 ]
 |  |  | cap = 8
 |  |  \_
 |  | @T moved = (realloc)[ me.data AS @ABYSS | cap * SIZE [ T ] ] AS @T
 |  | IF [ moved == NULL ]
 |  |  | (puts)[ "Vector: out of memory" ]
 |  |  | (exit)[ 1 ]
 |  |  \_
 |  | me.data = moved
 |  | me.cap = cap
 |  \_
 \_

CLASS Vector<T>: VectorData<T> IMPL [ VectorOps<T> ]
