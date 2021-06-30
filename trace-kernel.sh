#!/bin/bash
source constant.sh

help() {
    echo "./trace-kernel.sh initProgram [local=true]"
    echo "The third argument is for observe a local view."
}

trace-kernel() {
    if [ $# -eq 2 ]; then
        echo "Parsing LOCAL raw trace ..."
        awkoption="--assign local=true"
    else
        echo "Parsing GLOBAL raw trace ..."
        awkoption=""
    fi
    make clean
    # rawtrace=$(mktemp --tmpdir=/tmp cozart-XXXXX)
    $qemubin -trace exec_tb_block -smp $cores -m $mem -cpu $cpu \
        -drive file="$workdir/qemu-disk.ext4,if=virtio,format=raw" \
        -kernel $kernelbuild/$linux/$base/base/vmlinuz* -nographic -no-reboot \
        -append "nokaslr panic=-1 console=ttyS0 root=/dev/vda rw init=$1" \
        3>&1 1>trace-stdout.tmp 2>&3 | awk $awkoption --file extract-trace.awk > unsorted-trace.tmp

    cat unsorted-trace.tmp | sort >trace.tmp

    tracecnt=$(wc -l trace.tmp | cut -d' ' -f1)
    if [ $tracecnt -eq 0 ]; then
        echo "[Error] Trace contains 0 line."
        exit 1
    fi

    make get-modules
	echo "Getting module config information..."
    cat modules.tmp | ./module2config.sh >module.config.tmp &

	echo "Getting line information..."
    cat trace.tmp | ./trace2line.sh >lines.tmp &
    cat trace.tmp | awk /ffffffffc0/'{print $0}' | sort | ./trace2modline.sh \
        >lines.mod.tmp &

    wait

	echo "Getting directive config information..."
	cat lines.tmp | ./line2directive-config.sh >directive.config.tmp &
	cat lines.mod.tmp | ./line2directive-config.sh >directive.mod.config.tmp &

	echo "Getting filename config information..."
	cat lines.tmp | ./line2filename-config.sh >filename.config.tmp &
	cat lines.mod.tmp | ./line2filename-config.sh >filename.mod.config.tmp &

    wait

	echo "Combining all configs..."
	cat directive.config.tmp directive.mod.config.tmp filename.config.tmp \
        filename.mod.config.tmp  module.config.tmp | sed '/^$/d' | sort | \
        uniq >imm.config.tmp

	echo "Including config dependencies"
    cat imm.config.tmp | python3 include-dep.py | sort | uniq >final.config.tmp

}

if (test $# -ne 1) && (test $# -ne 2); then
    help
    exit 1
fi

trace-kernel $@

