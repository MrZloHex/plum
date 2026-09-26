; A generic library reached three ways -- directly, through another file,
; and by a path that walks out and back -- is included once: one template,
; one instance, one global.

!USES <../../extern/stdio.pl>
!USES <lib/box.pl>
!USES <a/user.pl>
!USES <a/../lib/box.pl>
I32 main: []
 | Box<I32> b
 | b.v = 5
 | (printf)[ "%d %d %d\n" | (b.get)[] + (use_a)[] | box_version | SIZE [ Box<I32> ] AS I32 ]
 | RET [ 0 ]
 \_
