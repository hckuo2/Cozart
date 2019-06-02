#!/bin/bash
set -e
source constant.sh

help() {
	echo "aggregate-config.sh base config [configs ...]"
}
main() {
	if [ "$#" -lt 2 ]; then
		help
		exit 1
	fi
    tmp=$(mktemp)
    baseconfig=$1
	shift
    echo "Tmp config file: $tmp"
	configs=$@
	for config in $configs; do
        echo "Collect config for $config"
		cat $config >>$tmp
	done

    tmp2=$(mktemp)
    echo "Filter with the $baseconfig"
	# use the original config to determine the value
	python3 assign-config-value.py $baseconfig $tmp >$tmp2

    echo "Merge with allnoconfig"
    cd $linux
    ./scripts/kconfig/merge_config.sh -n $tmp2 &>merge.log
}

main $@
