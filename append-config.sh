#!/bin/bash
set -e
source constant.sh

help() {
	echo "append-config.sh app [apps ...]"
}
main() {
	if [ "$#" -lt 1 ]; then
		help
		exit 1
	fi
    for app in $@; do
        candidates=$(python3 assign-config-value.py config-db/$linux/$base/base.config \
            config-db/$linux/$base/$app.config | grep --invert-match '#')

        cnt=0
        while read -r line; do
            if ! grep --silent "$line" $linux/.config.old; then
                (( cnt += 1 ))
                echo $line | tee --append $linux/.config.old
            fi
        done <<< "$candidates"
        printf "New config for %s %d\n" $app $cnt
    done
}

main $@
