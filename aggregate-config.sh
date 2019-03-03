#!/bin/bash
linuxdir="linux-4.19.16"
help() {
	echo "aggregate-config.sh distro app [apps ...]"
}
main() {
	if [ "$#" -lt 2 ]; then
		help
		exit 1
	fi
	distro=$1
	shift
	apps=$@
	mv $linuxdir/.config $linuxdir/.config.old
	for app in $apps; do
		cat config-db/$distro/$app.config >>$linuxdir/.config
	done
	# leverage kernel's STA solver by make olddefconfig
	cd $linuxdir && make olddefconfig && mv .config ../config.tmp && cd ..
	# use the original config as a filter
	python3 filter-config.py $distro.config config.tmp >$linuxdir/.config
}
main $@
