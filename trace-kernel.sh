#!/bin/bash
source lib.sh

trace-kernel() {
    $qemubin -trace exec_tb_block -nographic \
        -cdrom $vanilla/hello.iso 2> trace.raw.tmp;

    echo "Parsing raw trace..."
    cat trace.raw.tmp | awk -f extract-trace.awk | sort | uniq > trace.tmp

    echo "Getting line information..."
    cat trace.tmp | ./trace2line.sh > lines.tmp

    echo "Getting kernel config imformation..."
    cat lines.tmp | ./line2kconfig.sh > kernel.config.tmp
}
trace-kernel "$1";

