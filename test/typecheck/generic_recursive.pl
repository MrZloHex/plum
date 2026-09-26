; a generic that instantiates itself with a bigger argument never ends
TYPE Bad<T>:
 | @Bad<@T> x
 \_
I32 main: []
 | Bad<I32> b
 | RET [ 0 ]
 \_
