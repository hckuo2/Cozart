#!/bin/bash
workdir="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null && pwd)"
qemudir="$workdir/qemu"
qemubin="$qemudir/x86_64-softmmu/qemu-system-x86_64"
linuxversion="4.18.0"
linuxdir="$workdir/linux-$linuxversion"

distro=$1
vanillaconfig="config-db/$distro/vanilla.config"
checkmark=$2

help() {
    echo "./trace-kernel.sh distro initProgram [local=true]"
    echo "The third argument is for observe a local view."
}

trace-kernel() {
	$qemubin -trace exec_tb_block -smp 2 -m 8G -cpu kvm64 \
		-drive file="$workdir/qemu-disk.ext4,if=ide,format=raw" \
		-kernel $distro.bzImage -nographic -no-reboot \
		-append "nokaslr panic=-1 console=ttyS0 root=/dev/sda rw init=$2" \
		2>trace.raw.tmp

	echo "Parsing raw trace ..."
    if [ -n $3 ]; then
        awk --assign local=true --file extract-trace.awk trace.raw.tmp | uniq >trace.tmp
    else
        awk --assign --file extract-trace.awk trace.raw.tmp | uniq >trace.tmp
    fi

	echo "Getting line information..."
	cat trace.tmp | ./trace2line.sh $distro >lines.tmp

	echo "Getting kernel config imformation..."
	cat lines.tmp | ./line2kconfig.sh >kernel.config.tmp

	echo "Getting driver config imformation..."
	cat lines.tmp | ./line2dconfig.sh >driver.config.tmp

	echo "Getting final config imformation..."
	cat kernel.config.tmp driver.config.tmp | sort | uniq >imm0.config.tmp
	python3 filter-config.py $vanillaconfig "imm0.config.tmp" \
		>$linuxdir/.config
}
if (test $# -ne 2) && (test $# -ne 3); then
    help
    exit 1
fi
trace-kernel $@

