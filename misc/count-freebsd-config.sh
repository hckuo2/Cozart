#!/usr/bin/env bash
shopt -s globstar

archs=(riscv powerpc amd64 i386 arm64 mips arm sparc64)
count() {
    find . -name NOTES | xargs cat | sed -E -n -f $1/sys/conf/makeLINT.sed | wc -l
}

# this is for release before 5.0.0
count_legacy() {
    find $1/sys -name LINT | xargs cat | sed -E -n -f parse-freebsd.sed | wc -l
}

pushd freebsd
releases=$(git --no-pager branch -r | grep '/release/' | sort -V)
# releases=(origin/release/12.0.0)
popd
echo ${subdirs[@]} | tee > result
for release in $releases; do
    pushd freebsd
    git checkout "$release"
    popd
    echo $release $(count_legacy freebsd) | tee >>result
done
