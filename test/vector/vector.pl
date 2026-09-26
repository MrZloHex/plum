; examples/vector.pl, in the syntax the compiler accepts: a generic STRUCT,
; an IFACE of methods over it, and a CLASS binding the two.

!USES <../../extern/stdio.pl>
!USES <../../extern/stdlib.pl>

TYPE VectorType<T>:
 | @T    data
 | USIZE size
 | USIZE cap
 \_

IFACE VectorFace<T>: [ @VectorType<T> me ]
 + PUBLIC:
 |
 | I8 init: [ USIZE base_cap ]
 |  | IF [ me == NULL ]
 |  |  | RET [ -1 ]
 |  |  \_
 |  |
 |  | me.data = (malloc)[ SIZE [ T ] * base_cap ] AS @T
 |  | IF [ me.data == NULL ]
 |  |  | RET [ -1 ]
 |  |  \_
 |  |
 |  | me.size = 0
 |  | me.cap  = base_cap
 |  | RET [ 0 ]
 |  \_
 |
 | ABYSS deinit: []
 |  | IF [ me == NULL ]
 |  |  | RET
 |  |  \_
 |  | (free)[ me.data AS @ABYSS ]
 |  | me.data = NULL
 |  | me.size = 0
 |  | me.cap  = 0
 |  \_
 |
 | I8 push_back: [ T element ]
 |  | IF [ me == NULL ]
 |  |  | RET [ -1 ]
 |  |  \_
 |  | IF [ me.size == me.cap ]
 |  |  | IF [ (me.reallocate)[] != 0 ]
 |  |  |  | RET [ -1 ]
 |  |  |  \_
 |  |  \_
 |  | me.data{me.size} = element
 |  | me.size += 1
 |  | RET [ 0 ]
 |  \_
 |
 | I8 insert: [ USIZE idx | T element ]
 |  | IF [ me == NULL || idx > me.size ]
 |  |  | RET [ -1 ]
 |  |  \_
 |  | IF [ me.size == me.cap ]
 |  |  | (me.reallocate)[]
 |  |  \_
 |  | (me.shift_right)[ idx ]
 |  | me.data{idx} = element
 |  | me.size += 1
 |  | RET [ 0 ]
 |  \_
 |
 | I8 remove: [ USIZE idx ]
 |  | IF [ me == NULL || idx >= me.size ]
 |  |  | RET [ -1 ]
 |  |  \_
 |  | (me.shift_left)[ idx ]
 |  | me.size -= 1
 |  | RET [ 0 ]
 |  \_
 |
 | B1 get: [ USIZE idx | @T out ]
 |  | IF [ me == NULL || idx >= me.size ]
 |  |  | RET [ FALSE ]
 |  |  \_
 |  | ?(out) = me.data{idx}
 |  | RET [ TRUE ]
 |  \_
 |
 | @T at: [ USIZE idx ]
 |  | RET [ @(me.data{idx}) ]
 |  \_
 |
 | USIZE size: []
 |  | RET [ me.size ]
 |  \_
 |
 | USIZE capacity: []
 |  | RET [ me.cap ]
 |  \_
 |
 + PRIVATE:
 |
 | I8 reallocate: []
 |  | USIZE new_cap = me.cap * 2
 |  | IF [ new_cap == 0 ]
 |  |  | new_cap = 4
 |  |  \_
 |  | @T temp = (realloc)[ me.data AS @ABYSS | SIZE [ T ] * new_cap ] AS @T
 |  | IF [ temp == NULL ]
 |  |  | RET [ -1 ]
 |  |  \_
 |  | me.data = temp
 |  | me.cap  = new_cap
 |  | RET [ 0 ]
 |  \_
 |
 | ABYSS shift_right: [ USIZE idx ]
 |  | USIZE i = me.size
 |  | WHILE [ i > idx ]
 |  |  | me.data{i} = me.data{i - 1}
 |  |  | i -= 1
 |  |  \_
 |  \_
 |
 | ABYSS shift_left: [ USIZE idx ]
 |  | USIZE i = idx
 |  | WHILE [ i + 1 < me.size ]
 |  |  | me.data{i} = me.data{i + 1}
 |  |  | i += 1
 |  |  \_
 |  \_
 \_

CLASS Vector<T>: VectorType<T> IMPL [ VectorFace<T> ]

TYPE my_struct:
 | U8 smth
 | B1 flag
 \_

; an alias of an instance still has the class's methods
TYPE IntVec: Vector<I32>

I32 sum: [ @IntVec v ]
 | I32 total = 0
 | USIZE i = 0
 | WHILE [ i < (v.size)[] ]
 |  | total += ?((v.at)[ i ])
 |  | i += 1
 |  \_
 | RET [ total ]
 \_

I32 main: [ I32 argc | @@C1 argv ]
 | Vector<my_struct> vec
 | (vec.init)[ 2 ]
 |
 | my_struct s
 | s.flag = TRUE
 | U8 k = 0
 | WHILE [ k < 5 ]
 |  | s.smth = k * 10
 |  | (vec.push_back)[ s ]
 |  | k += 1
 |  \_
 |
 | @Vector<my_struct> vec_pointer = @vec
 | USIZE cap = (vec_pointer.capacity)[]
 | (printf)[ "SIZE %zu CAPACITY %zu\n" | (vec_pointer.size)[] | cap ]
 |
 | my_struct got
 | IF [ (vec.get)[ 3 | @got ] ]
 |  | (printf)[ "vec[3].smth = %d\n" | got.smth ]
 |  \_
 | IF [ !(vec.get)[ 9 | @got ] ]
 |  | (printf)[ "vec[9] is out of range\n" ]
 |  \_
 |
 | IntVec nums
 | (nums.init)[ 1 ]
 | I32 i = 1
 | WHILE [ i <= 4 ]
 |  | (nums.push_back)[ i * i ]
 |  | i += 1
 |  \_
 | (nums.insert)[ 0 | 100 ]
 | (nums.remove)[ 2 ]
 | (printf)[ "nums:" ]
 | USIZE j = 0
 | WHILE [ j < (nums.size)[] ]
 |  | (printf)[ " %d" | ?((nums.at)[ j ]) ]
 |  | j += 1
 |  \_
 | (printf)[ "  sum %d\n" | (sum)[ @nums ] ]
 |
 | ; nested instances, and `>>` closing two argument lists
 | Vector<Vector<I32>> grid
 | (grid.init)[ 2 ]
 | (grid.push_back)[ nums ]
 | (printf)[ "grid[0][0] = %d\n" | ?(((grid.at)[ 0 ]).data) ]
 |
 | (vec.deinit)[]
 | (nums.deinit)[]
 | (grid.deinit)[]
 | RET [ 0 ]
 \_
