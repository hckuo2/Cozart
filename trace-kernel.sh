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
	$qemubin -trace exec_tb_block -smp 2 -m 8G -cpu kvm64 \
		-drive file="$workdir/qemu-disk.ext4,if=ide,format=raw" \
		-kernel $distro.bzImage -nographic -no-reboot \
		-append "nokaslr panic=-1 console=ttyS0 root=/dev/sda rw init=$2" \
		2>trace.raw.tmp

    if [ $# -eq 3 ]; then
        echo "Parsing LOCAL raw trace ..."
        awk --assign local=true --file extract-trace.awk trace.raw.tmp | sort | uniq >trace.tmp
    else
        echo "Parsing GLOBAL raw trace ..."
        awk --file extract-trace.awk trace.raw.tmp | sort | uniq >trace.tmp
    fi

    make get-modules
	echo "Getting line information..."
	cat trace.tmp | ./trace2line.sh $distro >lines.tmp
    cat trace.tmp | awk /ffffffffc0/'{print $0}' | sort | ./trace2modline.sh \
        >> lines.tmp

	echo "Getting directive config information..."
	cat lines.tmp | ./line2kconfig.sh >kernel.config.tmp

	echo "Getting filename config information..."
	cat lines.tmp | ./line2dconfig.sh >driver.config.tmp

	echo "Getting module config information..."
    cat modules.tmp | ./module2config.sh $distro >module.config.tmp

	echo "Combining all configs..."
	cat kernel.config.tmp driver.config.tmp module.config.tmp | sort | uniq \
        >imm.config.tmp

	echo "Including config dependencies"
    cat imm.config.tmp | python3 include-dep.py | sort | uniq >final.config

}

if (test $# -ne 2) && (test $# -ne 3); then
    help
    exit 1
fi

trace-kernel $@

