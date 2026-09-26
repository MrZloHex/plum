; a generic type takes exactly as many arguments as it declares
TYPE Pair<A | B>:
 | A first
 | B second
 \_

I32 main: []
 | Pair<I32> p
 | RET [ 0 ]
 \_
