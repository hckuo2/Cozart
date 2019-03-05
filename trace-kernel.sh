#!/bin/bash
source lib.sh

trace-kernel() {
    $qemubin -trace exec_tb_block -nographic \
        -cdrom $vanilla/$1.iso 2> trace.raw.tmp;

    echo "Parsing raw trace..."
    cat trace.raw.tmp | awk -f extract-trace.awk | sort | uniq > trace.tmp

    echo "Getting line information..."
    cat trace.tmp | ./trace2line.sh > lines.tmp

    echo "Getting kernel config"
    cat lines.tmp | ./line2kconfig.sh > kernel.config.tmp

    echo "Including config dependencies"
    cat kernel.config.tmp | python3 include-dep.py > globalconfig.out

}
trace-kernel "$1";

