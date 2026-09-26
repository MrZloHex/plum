; Fixed-size arrays `T name{N}` and indexing `x{i}`: locals, globals,
; struct fields, arrays of structs, and pointers indexed the same way.

!USES <../../extern/stdio.pl>
!USES <../../extern/stdlib.pl>

TYPE Point:
 | I32 x
 | I32 y
 \_

TYPE Name:
 | C1  text{16}
 | I32 len
 \_

I32 squares{10}
F64 weights{3}

I32 sum: [ @I32 xs | I32 n ]
 | I32 total = 0
 | I32 i = 0
 | WHILE [ i < n ]
 |  | total += xs{i}
 |  | i += 1
 |  \_
 | RET [ total ]
 \_

ABYSS set_name: [ @Name nm | @C1 s ]
 | nm.len = 0
 | WHILE [ s{nm.len} != '\0' && nm.len < 15 ]
 |  | nm.text{nm.len} = s{nm.len}
 |  | nm.len += 1
 |  \_
 | nm.text{nm.len} = '\0'
 \_

I32 main: []
 | I32 i = 0
 | WHILE [ i < 10 ]
 |  | squares{i} = i * i
 |  | i += 1
 |  \_
 | ; an array passes as a pointer to its first element
 | (printf)[ "sum of squares %d, squares{9} %d\n" | (sum)[ squares | 10 ] | squares{9} ]
 |
 | C1 buf{32}
 | U8 k = 0
 | WHILE [ k < 5 ]
 |  | buf{k} = 'a' + k
 |  | k += 1
 |  \_
 | buf{5} = '\0'
 | (puts)[ buf ]
 | (printf)[ "@buf == buf: %d, ?buf = %c, (buf + 2){1} = %c\n" | @buf == buf | ?buf | (buf + 2){1} ]
 |
 | Point pts{4}
 | I32 j = 0
 | WHILE [ j < 4 ]
 |  | pts{j}.x = j
 |  | pts{j}.y = j * 10
 |  | j += 1
 |  \_
 | @Point p = pts + 2
 | (printf)[ "pts{3}.y %d, p.x %d, %d bytes\n" | pts{3}.y | p.x | SIZE [ Point ] * 4 ]
 |
 | Name nm
 | (set_name)[ @nm | "plum" ]
 | (printf)[ "name %s (%d), text{1} %c\n" | nm.text | nm.len | nm.text{1} ]
 |
 | weights{0} = 0.25
 | weights{1} = 0.5
 | weights{2} = weights{0} + weights{1}
 | (printf)[ "weights{2} %.2f\n" | weights{2} ]
 |
 | ; a pointer from malloc indexes the same way
 | @I32 heap = (malloc)[ 4 * SIZE [ I32 ] ] AS @I32
 | heap{0} = 7
 | heap{3} = heap{0} * 6
 | (printf)[ "heap{3} %d\n" | heap{3} ]
 | (free)[ heap AS @ABYSS ]
 | RET [ 0 ]
 \_
