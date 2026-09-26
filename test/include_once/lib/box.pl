TYPE BoxData<T>:
 | T v
 \_
IFACE BoxOps<T>: [ @BoxData<T> me ]
 | T get: []
 |  | RET [ me.v ]
 |  \_
 \_
CLASS Box<T>: BoxData<T> IMPL [ BoxOps<T> ]
I32 box_version = 3
