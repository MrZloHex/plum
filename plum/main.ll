@.str.0 = constant [17 x i8] c"Hello from PLUM!\00"

define dso_local i32 @main(i32 noundef %argc, ptr noundef %argv) {
  %argc_addr = alloca i32
  store i32 %argc, i32* %argc_addr
  %argv_addr = alloca ptr
  store ptr %argv, ptr %argv_addr
  %str = alloca ptr
  %r1 = alloca ptr
  store ptr @.str.0, ptr %r1
  %r0 = load ptr, ptr %r1
  store ptr %r0, ptr %str
  %r2 = load ptr, ptr %str
  call i32 @puts(ptr %r2)
  %is_args = alloca i8
  %r4 = add i8 0, 0
  %r5 = load i8, i8* %argc_addr
  %r6 = icmp sgt i8 %r5, %r4
  %r3 = zext i1 %r6 to i8
  store i8 %r3, i8* %is_args
  %r7 = load i8, i8* %is_args
  %r8 = trunc i8 %r7 to i1
  %r9 = icmp eq i1 %r8, 1
  br i1 %r9, label %l1, label %l3
l1:
  %r10 = load ptr, ptr %argv_addr
  call i32 @puts(ptr %r10)
  br label %l3
l3:
  %r11 = add i32 0, 0
  ret i32 %r11
}

declare i32 @puts(ptr noundef )

