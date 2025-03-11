#!/bin/bash

pushd $1
../../bin/plc $1.pl -o $1.ll --emit=IR
llvm-as $1.ll -o $1.bc 
clang $1.bc -o $1
popd

if [[ $2 == "-c" ]]; then
    ./$1/$1
    RES=$?
    if [[ $3 == "-r" ]]; then
        echo $RES
    fi
fi
