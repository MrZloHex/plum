#!/bin/bash

WITH_EXE=false
WITH_RES=false

set -ex

while [[ $# -gt 0 ]]; do
    case "$1" in
        -c)
            WITH_EXE=true
            shift 1
            ;;
        -r)
            WITH_RES=true
            shift 1
            ;;
        *) break
    esac
done


../bin/plc main.pl -o main.ll --emit=IR
llvm-as main.ll -o main.bc 
clang main.bc -o main

if $WITH_EXE; then
    ./main $@
    RES=$?
    if $WITH_RES; then
        echo $RES
    fi
fi
