; ModuleID = 'my_module'
source_filename = "my_module"

define i32 @foo() {
entry:
  %"+" = alloca i32, align 4
  store i32 0, ptr %"+", align 4
  ret i32 0
}

define i32 @main() {
entry:
  %"34" = alloca i32, align 4
  store i32 0, ptr %"34", align 4
  %"69" = alloca i32, align 4
  store i32 0, ptr %"69", align 4
  ret i32 0
}
