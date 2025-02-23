#!/bin/bash

set -ex

bison -d parser.y
flex lexer.l
gcc -o my_compiler parser.tab.c lex.yy.c ast.c llvm_codegen.c -I/usr/lib/llvm/18/include -D_GNU_SOURCE -D__STDC_CONSTANT_MACROS -D__STDC_FORMAT_MACROS -D__STDC_LIMIT_MACROS -L/usr/lib/llvm/18/lib64 -lLLVM-18 -lfl


