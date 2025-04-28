@.str.0 = constant [60 x i8] c"Usage: %s [--emit=<AST|IR>] [-o output] file1 [file2 ...]%c\00"
@.str.1 = constant [66 x i8] c"%c--emit=<AST|IR>   Specify the output type to emit (AST or IR)%c\00"
@.str.2 = constant [49 x i8] c"%c-o output        Specify the output filename%c\00"
@.str.3 = constant [57 x i8] c"%cfile1 ...        One or more source files to compile%c\00"
@.str.4 = constant [26 x i8] c"Current working dir: %s%c\00"

define dso_local void @usage(ptr noundef %progname) {
  %progname_addr = alloca ptr
  store ptr %progname, ptr %progname_addr
  %r1 = alloca ptr
  store ptr @.str.0, ptr %r1
  %r0 = load ptr, ptr %r1
  %r2 = load ptr, ptr %progname_addr
  %r3 = add i8 0, 10
  call i32 @printf(ptr %r0, ptr %r2, i8 %r3)
  %r5 = alloca ptr
  store ptr @.str.1, ptr %r5
  %r4 = load ptr, ptr %r5
  %r6 = add i8 0, 9
  %r7 = add i8 0, 10
  call i32 @printf(ptr %r4, i8 %r6, i8 %r7)
  %r9 = alloca ptr
  store ptr @.str.2, ptr %r9
  %r8 = load ptr, ptr %r9
  %r10 = add i8 0, 9
  %r11 = add i8 0, 10
  call i32 @printf(ptr %r8, i8 %r10, i8 %r11)
  %r13 = alloca ptr
  store ptr @.str.3, ptr %r13
  %r12 = load ptr, ptr %r13
  %r14 = add i8 0, 9
  %r15 = add i8 0, 10
  call i32 @printf(ptr %r12, i8 %r14, i8 %r15)
  ret void
}

define dso_local i32 @main(i32 noundef %argc, ptr noundef %argv) {
  %argc_addr = alloca i32
  store i32 %argc, i32* %argc_addr
  %argv_addr = alloca ptr
  store ptr %argv, ptr %argv_addr
  %cwd = alloca ptr
  %r16 = call ptr @get_current_dir_name()
  store ptr %r16, ptr %cwd
  %r18 = add i8 0, 0
  %r19 = load i8, i8* %cwd
  %r20 = icmp ne i8 %r19, %r18
  %r17 = zext i1 %r20 to i8
  %r21 = trunc i8 %r17 to i1
  %r22 = icmp eq i1 %r21, 1
  br i1 %r22, label %l1, label %l3
l1:
  %r24 = alloca ptr
  store ptr @.str.4, ptr %r24
  %r23 = load ptr, ptr %r24
  %r25 = load ptr, ptr %cwd
  %r26 = add i8 0, 10
  call i32 @printf(ptr %r23, ptr %r25, i8 %r26)
  br label %l3
l3:
  %progname = alloca ptr
  %r28 = load ptr, ptr %argv_addr
  %r27 = load ptr, ptr %r28
  store ptr %r27, ptr %progname
  %r29 = load ptr, ptr %progname
  call void @usage(ptr %r29)
  %r30 = load ptr, ptr %cwd
  call void @free(ptr %r30)
  %r31 = add i32 0, 0
  ret i32 %r31
}

declare i32 @puts(ptr noundef )
declare i32 @putchar(i32 noundef )
declare i32 @printf(ptr noundef , ...)
declare ptr @malloc(i64 noundef )
declare void @free(ptr noundef )
declare ptr @getcwd(ptr noundef , i64 noundef )
declare ptr @get_current_dir_name()

