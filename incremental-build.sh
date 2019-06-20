#!/bin/bash
source constant.sh

decompose_app() {
    # this function is a helper for application stacks and has no effect for
    # single application
    echo $1 | tr '+' ' '
}

old=$1
new=$2
tmp=`mktemp`
echo $new $base
space2newline() {
    tr " " "\n"
}
setup() {
    ./aggregate-config.sh \
        config-db/$linux/$base/base.config \
        config-db/$linux/$base/base-choice.config \
        config-db/$linux/$base/disable.config \
        config-db/$linux/$base/boot.config \
        $(locate_config_file $(decompose_app $old))
    pushd $linux
    make clean &> /dev/null
    make -j`nproc` &> /dev/null
    popd
    for app in disable boot base-choice $(decompose_app $old); do
        cat config-db/$linux/$base/$app.config >> $tmp;
    done
    sort -u -o $tmp $tmp
}

clean_cache() {
    sync; echo 3 | sudo tee /proc/sys/vm/drop_caches
}

incremental_build() {
    new_configs=`mktemp`
    comm -23 config-db/$linux/$base/$new.config $tmp >$new_configs
    python3 assign-config-value.py config-db/$linux/$base/base.config $new_configs \
       | grep -v '#' >> $linuxdir/.config
    pushd $linux
    make -j`nproc`
    popd
    printf "New config count %d\n" `wc -l $new_configs | awk '{print $1}'`
    cat $new_configs
}

setup
time incremental_build

