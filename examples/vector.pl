!USES <option.pl>
!USES <stdio.pl>

;;;;; IN OPTION

ENUM Option<T>:
 | None
 | Some<T>
 \_

;;;;;;;;;;;;;;

;;;;; IN STDIO

I32 printf[ CONST @CHAR format | ... ]
 | ;; IMPLEMENTATION
 \_

;;;;;;;;;;;


TYPE VectorType<T>:
 | @T     data
 |  USIZE size
 |  USIZE cap
 \_


IFACE VectorFace<T>: [ @VectorType<T> me ]
 - PUBLIC:
 |
 | I8 init: [ USIZE base_cap ]
 |  | IF [ me = NULL ]
 |  |  | RET [ #-1 ]
 |  |  \_
 |  |
 |  | @me.data = (malloc)[ base_cap ]
 |  | IF [ @me.data == NULL ]
 |  |  | RET [ #-1 ]
 |  | ELSE
 |  |  |
 |  |  \_
 |  |
 |  | @me.size = #0
 |  | @me.cap  = base_cap
 |  | 
 |  | RET [ #0 ]
 |  \_
 |
 | ABYSS deinit: []
 |  | IF [ me == NULL ]
 |  |  | RET []
 |  |  \_
 |  |
 |  | (free)[ @me.data ]
 |  | @me.data = NULL
 |  | @me.size = #0
 |  | @me.cap  = #0
 |  \_
 |
 | I8 push_back: [ T element ]
 |  | IF [ me = NULL ]
 |  |  | RET [ #-1 ]
 |  |  \_
 |  |
 |  | IF [ @me.size = @me.cap ]
 |  |  | (me.reallocate)[]
 |  |  \_
 |  |
 |  | @me.data{@me.size} = element
 |  | @me.size += 1
 |  \_
 |
 | I8 insert: [ USIZE idx | T element ]
 |  | IF [ me == NULL || idx >= @me.size ]
 |  |  | RET [ #-1 ]
 |  |  \_
 |  |
 |  | IF [ @me.size = @me.cap ]
 |  |  | (me.reallocate)[]
 |  |  \_
 |  |
 |  | (me.shift)[ idx ]
 |  | @me.data{idx} = element
 |  | @me.sizea    += #1
 |  | RET [ #0 ]
 |  \_
 |
 | I8 remove: [ USIZE idx ]
 |  | IF [ me == NULL || idx >= @me.size ]
 |  |  | RET [ #-1 ]
 |  |  \_
 |  |
 |  | (me.shift)[ idx ]
 |  | RET [ #0 ]
 |  \_
 |
 | Option<T> get: [ USIZE idx ]
 |  | IF [ me == NULL || idx >= @me.size ]
 |  |  | RET [ None ]
 |  |  \_
 |  |
 |  | RET [ Some [ @me.data{idx} ] ]
 |  \_
 |
 | USIZE size: []
 |  | RET [ @me.size ]
 |  \_
 |
 | USIZE capacity: []
 |  | RET [ @me.cap ]
 |  \_
 |
 |
 - PRIVATE:
 | 
 | I8 reallocate: []
 |  | USIZE new_cap = @me.cap * 2
 |  | @T temp = (realloc)[ @me.data | SIZEOF[ T ] * new_cap ]
 |  | IF [ temp == NULL ]
 |  |  | RET [ #-1 ]
 |  |  \_
 |  | @me.data = temp
 |  | @me.cap  = new_cap
 |  | RET [ #0 ]
 |  \_
 |
 | I8 shift: [ USIZE idx ]
 |  | FOR [ USIZE i = 0 | i < @me.size | i += 1 ]
 |  |  | @me.data{i} = @me.data{i+1}
 |  |  \_
 |  \_
 |
 \_


CLASS Vector<T>: VectorType<T> IMPL [ VectorFace<T> ]


TYPE my_struct:
 | U8 smth
 | BOOL flag
 \_

I32 main: [ I32 argc | @@C1 argv ]
 | Vector<my_struct> vec
 | (?vec.init)[ #16 ]
 |
 | @Vector<my_struct> vec_pointer = ?vec 
 |
 | USIZE cap = (vec_pointer.capacity)[]
 | (printf)[ "CAPACITY %zu\n" | cap ]
 |
 | (?vec.deinit)[]
 |
 | RET [ #0 ]
 \_





