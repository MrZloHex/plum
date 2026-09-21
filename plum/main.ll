; ModuleID = 'main'
source_filename = "main"
target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu"

@.str.0 = private unnamed_addr constant [60 x i8] c"Usage: %s [--emit=<AST|IR>] [-o output] file1 [file2 ...]%c\00"
@.str.1 = private unnamed_addr constant [66 x i8] c"%c--emit=<AST|IR>   Specify the output type to emit (AST or IR)%c\00"
@.str.2 = private unnamed_addr constant [49 x i8] c"%c-o output        Specify the output filename%c\00"
@.str.3 = private unnamed_addr constant [57 x i8] c"%cfile1 ...        One or more source files to compile%c\00"
@.str.4 = private unnamed_addr constant [26 x i8] c"Current working dir: %s%c\00"

declare i32 @puts(ptr)

declare i32 @putchar(i32)

declare i32 @printf(ptr, ...)

declare ptr @malloc(i64)

declare void @free(ptr)

declare ptr @getcwd(ptr, i64)

declare ptr @get_current_dir_name()

define void @usage(ptr %0) {
entry:
  %progname = alloca ptr, align 8
  store ptr %0, ptr %progname, align 8
  %progname1 = load ptr, ptr %progname, align 8
  %call = call i32 (ptr, ...) @printf(ptr @.str.0, ptr %progname1, i32 10)
  %call2 = call i32 (ptr, ...) @printf(ptr @.str.1, i32 9, i32 10)
  %call3 = call i32 (ptr, ...) @printf(ptr @.str.2, i32 9, i32 10)
  %call4 = call i32 (ptr, ...) @printf(ptr @.str.3, i32 9, i32 10)
  ret void
}

define void @parse_cli_opts() {
entry:
  ret void
}

define i32 @main(i32 %0, ptr %1) {
entry:
  %argc = alloca i32, align 4
  store i32 %0, ptr %argc, align 4
  %argv = alloca ptr, align 8
  store ptr %1, ptr %argv, align 8
  %cwd = alloca ptr, align 8
  %call = call ptr @get_current_dir_name()
  store ptr %call, ptr %cwd, align 8
  %cwd1 = load ptr, ptr %cwd, align 8
  %ne = icmp ne ptr %cwd1, null
  br i1 %ne, label %if.then, label %if.else

if.end:                                           ; preds = %if.else, %if.then
  %opt_output_file = alloca ptr, align 8
  %opt_emit_type = alloca ptr, align 8
  %file_start_index = alloca i32, align 4
  %progname = alloca ptr, align 8
  %argv4 = load ptr, ptr %argv, align 8
  %deref = load ptr, ptr %argv4, align 8
  store ptr %deref, ptr %progname, align 8
  %progname5 = load ptr, ptr %progname, align 8
  call void @usage(ptr %progname5)
  %cwd6 = load ptr, ptr %cwd, align 8
  call void @free(ptr %cwd6)
  ret i32 0

if.then:                                          ; preds = %entry
  %cwd2 = load ptr, ptr %cwd, align 8
  %call3 = call i32 (ptr, ...) @printf(ptr @.str.4, ptr %cwd2, i32 10)
  br label %if.end

if.else:                                          ; preds = %entry
  br label %if.end
}
