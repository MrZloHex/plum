#!/bin/bash

set -ex

bison -d parser.y
flex lexer.l
gcc -o parser parser.tab.c lex.yy.c ast.c -lfl

./parser < test.pl
