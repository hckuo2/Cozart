#!/usr/bin/env bash

count() {
    find $1 -name Kconfig -o -iname "Kconfig.*" | \
        xargs grep --only-matching -E "\bconfig [A-Z0-9_]+" | \
        cut -d':' -f2  | sort | uniq | wc -l
}

pushd linux-stable
tags=$(git tag)
popd
for tag in $tags; do
    pushd linux-stable
    git checkout $tag && git clean -f -d && git checkout -- .
    popd
    echo $tag $(count linux-stable) | tee >> result
done
