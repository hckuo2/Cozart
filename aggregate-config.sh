#!/bin/bash
set -e
source lib.sh

help() {
	echo "aggregate-config.sh distro app [apps ...]"
}
main() {
	if [ "$#" -lt 2 ]; then
		help
		exit 1
	fi
    tmp=$(mktemp)
	distro=$1
	shift
    echo "Tmp config file: $tmp"
	apps=$@
	for app in $apps; do
        echo "Collect config for $app"
		cat config-db/$distro/$app.config >>$tmp
	done

    tmp2=$(mktemp)
    echo "Filter with the $distro vanilla"
	# use the original config to determine the value
	python3 assign-config-value.py config-db/$distro/vanilla.config $tmp >$tmp2

    echo "Merge with allnoconfig"
    cd $linuxdir
    ./scripts/kconfig/merge_config.sh -n $tmp2 &>merge.log
}

main $@
