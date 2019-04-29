#!/usr/bin/env bash

subdirs=(arch crypto drivers fs include init ipc kernel lib mm net scripts \
    security sound usr)

count() {
    for dir in ${subdirs[@]}; do
        printf $(find "$1/$dir" -name Kconfig -o -iname "Kconfig.*" | \
            xargs grep --only-matching -E "\bconfig [A-Z0-9_]+" | \
            cut -d':' -f2  | sort | uniq | wc -l)
        printf " "
    done
    echo
}

pushd linux-stable
git reset --hard master && git checkout master && git clean -f -d
tags=$(git tag | sort -V)
popd
echo ${subdirs[@]} | tee > result
for tag in $tags; do
    pushd linux-stable
    git checkout $tag && git clean -f -d && git checkout -- .
    popd
    echo $tag $(count linux-stable) | tee >> result
done
