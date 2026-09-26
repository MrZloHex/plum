; Generic types with several parameters, pointer arguments, and classes
; with no parameters of their own that implement more than one IFACE.

!USES <../../extern/stdio.pl>
!USES <../../extern/stdlib.pl>

TYPE Pair<A | B>: STRUCT
 | A first
 | B second
 \_

TYPE Node<T>:
 | T        value
 | @Node<T> next
 \_

; a generic alias
TYPE Ref<T>: @T

Pair<I32 | @C1> make_pair: [ I32 n | @C1 s ]
 | Pair<I32 | @C1> p
 | p.first = n
 | p.second = s
 | RET [ p ]
 \_

I32 list_sum: [ @Node<I32> n ]
 | I32 total = 0
 | WHILE [ n != NULL ]
 |  | total += n.value
 |  | n = n.next
 |  \_
 | RET [ total ]
 \_

; --- a plain class, two interfaces ---------------------------------------

TYPE CounterData:
 | I32 count
 | I32 step
 \_

IFACE Counting: [ @CounterData me ]
 | ABYSS reset: [ I32 step ]
 |  | me.count = 0
 |  | me.step = step
 |  \_
 |
 | ABYSS tick: []
 |  | me.count += (me.scaled)[ 1 ]
 |  \_
 |
 + PRIVATE:
 | I32 scaled: [ I32 n ]
 |  | RET [ n * me.step ]
 |  \_
 \_

IFACE Reporting: [ @CounterData me ]
 | ABYSS report: [ @C1 label ]
 |  | ; a method of another IFACE, private one included, is in reach
 |  | (printf)[ "%s: %d (step %d)\n" | label | me.count | (me.scaled)[ 1 ] ]
 |  \_
 \_

CLASS Counter: CounterData IMPL [ Counting | Reporting ]

; --- a generic class over a generic base ---------------------------------

TYPE StackData<T>:
 | @Node<T> top
 | USIZE    depth
 \_

IFACE StackOps<T>: [ @StackData<T> me ]
 | ABYSS push: [ T v ]
 |  | @Node<T> n = (malloc)[ SIZE [ Node<T> ] ] AS @Node<T>
 |  | n.value = v
 |  | n.next = me.top
 |  | me.top = n
 |  | me.depth += 1
 |  \_
 |
 | T pop: []
 |  | @Node<T> n = me.top
 |  | T v = n.value
 |  | me.top = n.next
 |  | me.depth -= 1
 |  | (free)[ n AS @ABYSS ]
 |  | RET [ v ]
 |  \_
 |
 | B1 empty: []
 |  | RET [ me.top == NULL ]
 |  \_
 \_

CLASS Stack<T>: StackData<T> IMPL [ StackOps<T> ]

Stack<@C1> new_words: []
 | Stack<@C1> s
 | s.top = NULL
 | s.depth = 0
 | RET [ s ]
 \_

I32 main: []
 | Pair<I32 | @C1> p = (make_pair)[ 7 | "seven" ]
 | (printf)[ "pair: %d %s, %d bytes\n" | p.first | p.second | SIZE [ Pair<I32 | @C1> ] AS I32 ]
 |
 | Node<I32> a
 | Node<I32> b
 | a.value = 40
 | a.next = @b
 | b.value = 2
 | b.next = NULL
 | (printf)[ "list: %d\n" | (list_sum)[ @a ] ]
 |
 | I32 x = 5
 | Ref<I32> r = @x
 | ?(r) = ?(r) + 1
 | ; AS followed by `<` is still a comparison
 | IF [ x AS I32 < 7 && x AS I64 > 5 ]
 |  | (printf)[ "ref: %d\n" | x ]
 |  \_
 |
 | Counter c
 | (c.reset)[ 3 ]
 | (c.tick)[]
 | (c.tick)[]
 | (c.report)[ "counter" ]
 |
 | Stack<I32> st
 | st.top = NULL
 | st.depth = 0
 | I32 i = 0
 | WHILE [ i < 4 ]
 |  | (st.push)[ i ]
 |  | i += 1
 |  \_
 | (printf)[ "stack depth %d:" | st.depth AS I32 ]
 | WHILE [ !(st.empty)[] ]
 |  | (printf)[ " %d" | (st.pop)[] ]
 |  \_
 | (printf)[ "\n" ]
 |
 | ; a method called on a temporary
 | (printf)[ "fresh stack empty: %d\n" | (((new_words)[]).empty)[] ]
 | Stack<@C1> w = (new_words)[]
 | (w.push)[ "world" ]
 | (w.push)[ "hello" ]
 | @C1 first = (w.pop)[]
 | (printf)[ "%s %s\n" | first | (w.pop)[] ]
 | RET [ 0 ]
 \_
