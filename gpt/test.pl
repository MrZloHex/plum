; === Типы ===
TYPE MyInt: @I32

TYPE Point: STRUCT
 | F64 x
 | F64 y
 | F32 q
 \_

TYPE Shape: UNION
 | @Point p
 | @@I32 radius
 \_
 
TYPE Color: ENUM
 | RED
 | GREEN
 | BLUE
 \_

; Объявления внешних C-функций
ABYSS log: [ @C1 fmt | ... ]
@C1   malloc: [ USIZE size ]

; === Функция add (возвращает I32) ===
I32 add: [ I32 a | I32 b ]
;| I32 result = a + b
 | RET [ result ]
 \_

;; === Главная функция ===
;I32 main: []
; | ; переменные и указатели
; | I32 count    = 3
; | @I32 pcount  = @count
; | ?pcount      = ?pcount + 2    ; теперь count == 5
; |
; | ; вызов функции add
; | I32 sum = (add) [ count | 7 ]
; |
; | ; проверка if-elif-else
; | IF [ sum > 10 ]
; |  | (log) [ "Sum > 10\n" | sum ]
; | ELIF [ sum == 10 ]
; |  | (log) [ "Sum == 10\n" ]
; | ELSE
; |  | (log) [ "Sum < 10\n" | sum ]
; |  \_
;
; | ; цикл с BREAK
; | USIZE i = 0
; | LOOP
; |  | IF [ i >= 5 ]
; |  |  | BREAK
; |  |  \_
; |  | (log) [ "Loop i=%u\n" | i ]
; |  | i = i + 1
; |  \_
; |
; | ; sizeof
; | I32 size_point = SIZE [ Point ]
; |
; | ; структуры и доступ к полям
; | Point pt
; | pt.x = 1.0
; | pt.y = 2.0
; |
; | @Point p_pt = @pt
; | ?p_pt.x = 3.14
; |
; | ; объединения
; | Shape s1
; | s1.p      = pt
; | Shape s2
; | s2.radius = 42
; |
; | ; перечисления и булевы
; | Color c   = RED
; | B1    flag = TRUE
; | B1    neq  = (sum != 10)
; |
; | ; литералы
; | C1    ch    = '\n'
; | @C1   pch   = @ch
; | STRING msg  = "Hello, \\\"PLUM\\\"!\n"
; |
; | ; указатели и арифметика по указателям
; | @I32 arr = malloc(5 * SIZE [ I32 ])
; | I32 idx  = 0
; | LOOP
; |  | IF [ idx >= 5 ]
; |  |  | BREAK
; |  |  \_
; |  | ?arr     = idx * 2
; |  | arr      = arr + 1
; |  | idx      = idx + 1
; |  \_
; |
; | RET [ 0 ]
; \_
