; lib/vector.pl: every method, growth past the first capacity, struct
; elements edited in place, a vector of vectors, and pointers as elements.

!USES <../../lib/vector.pl>
!USES <../../extern/stdio.pl>

TYPE Sym:
 | @C1 name
 | I32 value
 \_

ABYSS show: [ @Vector<I32> v ]
 | (printf)[ "[" ]
 | USIZE i = 0
 | WHILE [ i < (v.size)[] ]
 |  | (printf)[ " %d" | ?((v.at)[ i ]) ]
 |  | i += 1
 |  \_
 | (printf)[ " ] size %lu\n" | (v.size)[] ]
 \_

I32 main: []
 | Vector<I32> v
 | (v.init)[ 0 ]
 | (printf)[ "empty %d, cap %lu\n" | (v.empty)[] | v.cap ]
 | I32 i = 0
 | WHILE [ i < 20 ]
 |  | (v.push)[ i * i ]
 |  | i += 1
 |  \_
 | (printf)[ "cap %lu, last %d\n" | v.cap | ?((v.last)[]) ]
 | (v.remove)[ 0 ]
 | (v.remove)[ 17 ]
 | (printf)[ "remove out of range: %d\n" | (v.remove)[ 99 ] ]
 | (v.pop)[]
 | (v.pop)[]
 | (show)[ @v ]
 | ?((v.at)[ 2 ]) = -1
 | (show)[ @v ]
 | (v.clear)[]
 | (v.pop)[]
 | (show)[ @v ]
 | (v.deinit)[]
 |
 | ; struct elements, changed through the pointer `at` gives
 | Vector<Sym> syms
 | (syms.init)[ 2 ]
 | Sym s
 | s.name = "alpha"
 | s.value = 1
 | (syms.push)[ s ]
 | s.name = "beta"
 | s.value = 2
 | (syms.push)[ s ]
 | s.name = "gamma"
 | s.value = 3
 | (syms.push)[ s ]
 | @Sym b = (syms.at)[ 1 ]
 | b.value = 20
 | (printf)[ "%s=%d %s=%d %s=%d\n" | (syms.at)[ 0 ].name | (syms.at)[ 0 ].value | (syms.at)[ 1 ].name | (syms.at)[ 1 ].value | (syms.at)[ 2 ].name | (syms.at)[ 2 ].value ]
 | (syms.deinit)[]
 |
 | ; a vector of vectors, and of pointers
 | Vector<Vector<C1>> rows
 | (rows.init)[ 1 ]
 | I32 r = 0
 | WHILE [ r < 3 ]
 |  | Vector<C1> row
 |  | (row.init)[ 1 ]
 |  | I32 k = 0
 |  | WHILE [ k <= r ]
 |  |  | (row.push)[ 'a' + r ]
 |  |  | k += 1
 |  |  \_
 |  | (row.push)[ '\0' ]
 |  | (rows.push)[ row ]
 |  | r += 1
 |  \_
 | (printf)[ "%s %s %s\n" | (rows.at)[ 0 ].data | (rows.at)[ 1 ].data | (rows.at)[ 2 ].data ]
 |
 | Vector<@C1> words
 | (words.init)[ 0 ]
 | (words.push)[ "one" ]
 | (words.push)[ "two" ]
 | (printf)[ "%s %s\n" | ?((words.at)[ 0 ]) | ?((words.last)[]) ]
 | RET [ 0 ]
 \_
