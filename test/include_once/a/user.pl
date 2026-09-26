!USES <../lib/box.pl>
I32 use_a: []
 | Box<I32> b
 | b.v = 10
 | RET [ (b.get)[] ]
 \_
