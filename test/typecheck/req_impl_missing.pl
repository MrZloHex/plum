; the type put for BUS is a class, but does not IMPL SPIBus
IFACE SPIBus<T>: [ @T me ]
 | I32 transfer: []
 |  | RET [ 0 ]
 |  \_
 \_
IFACE Plain<T>: [ @T me ]
 | I32 get: []
 |  | RET [ 0 ]
 |  \_
 \_
TYPE BusData: STRUCT
 | I32 n
 \_
CLASS Other: BusData IMPL [ Plain<BusData> ]
TYPE DevData<BUS>: STRUCT
 | @BUS bus
 \_
IFACE DevOps<T | BUS>: [ @T me ] REQ [ BUS IMPL SPIBus<BUS> ]
 | I32 f: []
 |  | RET [ 1 ]
 |  \_
 \_
CLASS Dev<BUS>: DevData<BUS> IMPL [ DevOps<DevData<BUS> | BUS> ]
I32 main: []
 | Dev<Other> d
 | RET [ 0 ]
 \_
