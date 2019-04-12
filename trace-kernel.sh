#!/bin/bash
source lib.sh

distro=$1
vanillaconfig="config-db/$distro/vanilla.config"

help() {
    echo "./trace-kernel.sh distro initProgram [local=true]"
    echo "The third argument is for observe a local view."
}

trace-kernel() {
    make clean
    rawtrace=$(mktemp)
    echo $rawtrace
	$qemubin -trace exec_tb_block -m $mem -M $machine -cpu $cpu -nographic \
        -dtb compiled-kernels/$distro/vanilla/boot/bcm2837-rpi-3-b.dtb \
        -kernel compiled-kernels/$distro/vanilla/vmlinuz-4.14.98-v8* \
        -drive file=qemu-disk.ext4,format=raw,if=sd \
        -no-reboot \
        -append "nokaslr rw panic=-1 earlycon=pl011,0x3f201000 console=ttyAMA0 loglevel=3 root=/dev/mmcblk0 init=$2" \
        2>$rawtrace

    if [ $# -eq 3 ]; then
        echo "Parsing LOCAL raw trace ..."
        awk --assign local=true --file extract-trace.awk $rawtrace | sort | uniq >trace.tmp
    else
        echo "Parsing GLOBAL raw trace ..."
        awk --file extract-trace.awk $rawtrace | sort | uniq >trace.tmp
    fi
    rm $rawtrace;

    make get-modules
	echo "Getting module config information..."
    cat modules.tmp | ./module2config.sh $distro >module.config.tmp &

	echo "Getting line information..."
    cat trace.tmp | ./trace2line.sh $distro >lines.tmp &
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

if (test $# -ne 2) && (test $# -ne 3); then
    help
    exit 1
fi

trace-kernel $@

