; interfaces.pl -- one class, several interfaces; one interface, several classes
;
; PLUM has no inheritance. A CLASS is a struct plus the methods of every
; IFACE it lists, so behaviour is composed, the way Rust traits or mixins
; are, rather than inherited:
;
;   * an IFACE written for `@T me` works for any struct with the fields its
;     methods touch: Movable<T> below serves three different structs
;   * a class lists what it can do: the player is Named, Movable, Mortal
;     and a Collector; a coin is only Named and Movable
;   * methods reach each other through `me`, across interfaces: Mortal
;     calls `say`, which comes from Named
;   * REQ says what an interface needs: Mortal needs an I32 hp, and a
;     class that is Named too. Give Coin Mortal<CoinData>, and plc says
;     `Coin` cannot IMPL Mortal<CoinData>: it has no field `hp` (I32),
;     at the CLASS line.
;
;   plc --emit=OBJ interfaces.pl -o interfaces.o && clang interfaces.o -o interfaces

!USES <../extern/stdio.pl>

; --- the data: three different structs ---------------------------------------

TYPE PlayerData: STRUCT
 | @C1 name
 | I32 x
 | I32 y
 | I32 hp
 | I32 score
 \_

TYPE EnemyData: STRUCT
 | @C1 name
 | I32 x
 | I32 y
 | I32 hp
 \_

TYPE CoinData: STRUCT
 | @C1 name
 | I32 x
 | I32 y
 | I32 value
 \_

; --- behaviour, each written once --------------------------------------------

; anything with a name
IFACE Named<T>: [ @T me ] REQ [ @C1 name ]
 | ABYSS say: [ @C1 what ]
 |  | (printf)[ "%-7s %s\n" | me.name | what ]
 |  \_
 \_

; anything with a position
IFACE Movable<T>: [ @T me ] REQ [ I32 x | I32 y ]
 | ABYSS move_by: [ I32 dx | I32 dy ]
 |  | me.x += dx
 |  | me.y += dy
 |  \_
 |
 | ; in steps along the grid
 | I32 distance_to: [ I32 x | I32 y ]
 |  | RET [ (abs_i32)[ me.x - x ] + (abs_i32)[ me.y - y ] ]
 |  \_
 \_

; anything with hit points. It speaks through `say`, so a class that is
; Mortal must be Named too.
IFACE Mortal<T>: [ @T me ] REQ [ I32 hp | Named<T> ]
 | ABYSS hit: [ I32 damage ]
 |  | me.hp -= damage
 |  | IF [ me.hp <= 0 ]
 |  |  | me.hp = 0
 |  |  | (me.say)[ "is defeated" ]
 |  | ELSE
 |  |  | (me.report)[]
 |  |  \_
 |  \_
 |
 | B1 alive: []
 |  | RET [ me.hp > 0 ]
 |  \_
 |
 + PRIVATE:
 | ABYSS report: []
 |  | C1 buf{32}
 |  | (snprintf)[ buf | 32 | "has %d hp left" | me.hp ]
 |  | (me.say)[ buf ]
 |  \_
 \_

; only a player collects, so this one is written for PlayerData alone
IFACE Collector: [ @PlayerData me ] REQ [ Named<PlayerData> ]
 | ABYSS collect: [ @Coin c ]
 |  | me.score += c.value
 |  | (me.say)[ "picks up a coin" ]
 |  \_
 \_

; --- the classes: the data, and what it can do -------------------------------

CLASS Player: PlayerData IMPL [ Named<PlayerData> | Movable<PlayerData> | Mortal<PlayerData> | Collector ]
CLASS Enemy: EnemyData IMPL [ Named<EnemyData> | Movable<EnemyData> | Mortal<EnemyData> ]
CLASS Coin: CoinData IMPL [ Named<CoinData> | Movable<CoinData> ]

I32 abs_i32: [ I32 v ]
 | IF [ v < 0 ]
 |  | RET [ -v ]
 |  \_
 | RET [ v ]
 \_

; --- runtime polymorphism, by hand -------------------------------------------
;
; Everything above is resolved at compile time: there is no value of type
; "anything Movable". When one list must hold different kinds of things, a
; function pointer and an untyped pointer make that by hand -- which is
; what a C++ virtual call does behind the scenes.

TYPE Actor: STRUCT
 | @ABYSS                 self
 | FN ABYSS [ @ABYSS ]    turn
 \_

ABYSS player_turn: [ @ABYSS self ]
 | @Player p = self AS @Player
 | (p.say)[ "waits" ]
 \_

ABYSS enemy_turn: [ @ABYSS self ]
 | @Enemy e = self AS @Enemy
 | IF [ !(e.alive)[] ]
 |  | RET
 |  \_
 | (e.move_by)[ -1 | 0 ]
 | (e.say)[ "creeps closer" ]
 \_

; -----------------------------------------------------------------------------

I32 main: []
 | Player p
 | p.name = "hero"
 | p.x = 0
 | p.y = 0
 | p.hp = 10
 | p.score = 0
 |
 | Enemy e
 | e.name = "goblin"
 | e.x = 3
 | e.y = 4
 | e.hp = 10
 |
 | Coin c
 | c.name = "coin"
 | c.x = 1
 | c.y = 1
 | c.value = 5
 |
 | (p.say)[ "enters the cave" ]
 | (p.move_by)[ 1 | 1 ]
 | (p.collect)[ @c ]
 | (printf)[ "the goblin is %d steps away\n" | (p.distance_to)[ e.x | e.y ] ]
 |
 | (e.hit)[ 4 ]
 | (p.hit)[ 3 ]
 | (e.hit)[ 7 ]
 |
 | ; different classes, one list, one call
 | Actor actors{2}
 | actors{0}.self = @p AS @ABYSS
 | actors{0}.turn = player_turn
 | actors{1}.self = @e AS @ABYSS
 | actors{1}.turn = enemy_turn
 | I32 i = 0
 | WHILE [ i < 2 ]
 |  | (actors{i}.turn)[ actors{i}.self ]
 |  | i += 1
 |  \_
 |
 | (printf)[ "hero: hp %d, score %d, alive %d; goblin alive %d\n" | p.hp | p.score | (p.alive)[] | (e.alive)[] ]
 | RET [ 0 ]
 \_
