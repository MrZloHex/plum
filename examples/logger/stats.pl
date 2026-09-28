; stats.pl -- what the samples add up to

!USES <sensor.pl>
!USES <../../lib/vector.pl>
!USES <../option.pl>

TYPE Range<T>: STRUCT
 | T lo
 | T hi
 \_

Celsius mean_of: [ @Vector<Celsius> v ]
 | Celsius sum = 0.0
 | USIZE i = 0
 | WHILE [ i < (v.size)[] ]
 |  | sum += ?((v.at)[ i ])
 |  | i += 1
 |  \_
 | RET [ sum / ((v.size)[] AS F32) ]
 \_

; the lowest and highest, or nothing when there were no samples
Option<Range<Celsius>> range_of: [ @Vector<Celsius> v ]
 | IF [ (v.empty)[] ]
 |  | RET [ (Option<Range<Celsius>>.none)[] ]
 |  \_
 | Range<Celsius> r
 | r.lo = ?((v.at)[ 0 ])
 | r.hi = r.lo
 | USIZE i = 1
 | WHILE [ i < (v.size)[] ]
 |  | Celsius x = ?((v.at)[ i ])
 |  | IF [ x < r.lo ]
 |  |  | r.lo = x
 |  | ELIF [ x > r.hi ]
 |  |  | r.hi = x
 |  |  \_
 |  | i += 1
 |  \_
 | RET [ (Option<Range<Celsius>>.some)[ r ] ]
 \_
