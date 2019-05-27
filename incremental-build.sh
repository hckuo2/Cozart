#!/bin/bash
source lib.sh

decompose_app() {
    # this function is a helper for application stacks and has no effect for
    # single application
    echo $1 | tr '+' ' '
}

base=$1
new=$2
tmp=`mktemp`
echo $new $base
space2newline() {
    tr " " "\n"
}
setup() {
    ./aggregate-config.sh $distro disable boot vanilla-choice $(decompose_app $base)
    pushd $linuxdir
    make clean &> /dev/null
    make -j`nproc` &> /dev/null
    popd
    for app in disable boot vanilla-choice $(decompose_app $base); do
        cat config-db/$distro/$app.config >> $tmp;
    done
    sort -u -o $tmp $tmp
}

incremental_build() {
    new_configs=`mktemp`
    comm -23 config-db/$distro/$new.config $tmp >$new_configs
    python3 assign-config-value.py config-db/$distro/vanilla.config $new_configs \
       | grep -v '#' >> $linuxdir/.config
    pushd $linuxdir
    make -j`nproc`
    popd
    printf "New config count %d\n" `wc -l $new_configs | awk '{print $1}'`
    cat $new_configs
}

setup
time incremental_build

