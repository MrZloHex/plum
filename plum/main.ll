@.str.0 = constant [8 x i8] c"QWE qwe\00"
@.str.1 = constant [10 x i8] c"PLUM PLUM\00"

define dso_local i32 @main(i32 noundef %argc, ptr noundef %argv) {
  %argc_addr = alloca i32
  store i32 %argc, i32* %argc_addr
  %argv_addr = alloca ptr
  store ptr %argv, ptr %argv_addr
  %stdout = alloca ptr
  %r0 = add ptr 0, 0
  store ptr %r0, ptr %stdout
  %r2 = alloca ptr
  store ptr @.str.0, ptr %r2
  %r1 = load ptr, ptr %r2
  %r3 = load ptr, ptr %stdout
  call i32 @fputs(ptr %r1, ptr %r3)
  %r5 = alloca ptr
  store ptr @.str.1, ptr %r5
  %r4 = load ptr, ptr %r5
  call i32 @puts(ptr %r4)
  %r6 = add i32 0, 0
  ret i32 %r6
}

declare i32 @puts(ptr noundef )
declare i32 @putchar(i32 noundef )
declare i32 @fputs(ptr noundef , ptr noundef )
declare ptr @getcwd(ptr noundef , i64 noundef )
declare ptr @get_current_dir_name()

