#!/bin/bash

WITH_EXE=false
WITH_RES=false
TEST="simplest"

set -e

while [[ $# -gt 0 ]]; do
    case "$1" in
        -t)
            TEST=$2
            shift 2
            ;;
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

pushd $TEST
../../bin/plc $TEST.pl -o $TEST.ll --emit=IR
llvm-as $TEST.ll -o $TEST.bc 
clang $TEST.bc -o $TEST
popd

if $WITH_EXE; then
    ./$TEST/$TEST $@
    RES=$?
    if $WITH_RES; then
        echo $RES
    fi
fi
