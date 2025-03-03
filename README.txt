
  	░▒▓███████▓▒░░▒▓█▓▒░     ░▒▓█▓▒░░▒▓█▓▒░▒▓██████████████▓▒░
  	░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░     ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░
  	░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░     ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░
  	░▒▓███████▓▒░░▒▓█▓▒░     ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░
  	░▒▓█▓▒░      ░▒▓█▓▒░     ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░
  	░▒▓█▓▒░      ░▒▓█▓▒░     ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░
  	░▒▓█▓▒░      ░▒▓████████▓▒░▒▓██████▓▒░░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░


  ░▒▓█ _PLUM_█▓▒░
  The **PLUM** is a programming language — compiling low-level, C-compatible.

  ───────────────────────────────────────────────────────────────
  ▓ OVERVIEW
  The **PLUM** is designed to be modular and pluggable,
  it supports external functions, enabling integration
  with C libraries for greater flexibility. The compiler uses **Bison** and
  **Flex** for syntax parsing and can emit either **LLVM IR** or **AST**.

  **Features at a glance:**
  ▪ Modular and pluggable architecture
  ▪ External function support from C-ABI
  ▪ Support for generating **LLVM IR** or **AST**
  ▪ Self-hosted in development

  ───────────────────────────────────────────────────────────────
  ▓ LANGUAGE OVERVIEW

  ```plum
  ; hello.pl 

  ABYSS println: [ @C1 str ]
   | I32 newline
   | newline = '\n'
   | (puts)[str]
   | (putchar)[newline]
   | RET []
   \_

  I32 main: []
   | @C1 str
   | str = "Hello from PLUM!"
   | (println)[ str ]
   | RET [ 0 ]
   \_

  I32 puts:    [ @C1 str ]
  I32 putchar: [ I32 char ]
  ```

  ───────────────────────────────────────────────────────────────
  ▓ BUILD & RUN

  ▪ **For compiling PLUM code**
  ```sh
  make
  ```

  ▪ **To run the compiler**
  ```sh
  ./bin/plc --emit=<AST|IR> [-o output] file1 [file2 ...]
  ```

  ▪ **To test**
  ```sh
  cd test
  ./build.sh <test> -c
  ```
  E.g. Make *hello world* programme, run:
  ```sh
  ./build.sh c_call -c
  ```

 ───────────────────────────────────────────────────────────────
 ▓ FINAL WORDS
 This is not just a programming language.
