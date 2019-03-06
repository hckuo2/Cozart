#!/bin/bash
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
    echo $tmp
	distro=$1
	shift
	apps=$@
	for app in $apps; do
		cat config-db/$distro/$app.config >>$tmp
	done
	# use the original config as a filter
	python3 filter-config.py config-db/$distro/vanilla.config $tmp >$linuxdir/.config
}
main $@
