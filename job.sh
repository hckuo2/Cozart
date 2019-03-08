#!/bin/bash
set -e
source lib.sh

trace() {
    for app in $@; do
        echo "Tracing $app"
        ./trace-kernel.sh ubuntu /benchmark-scripts/$app.sh true;
        cp final.config.tmp config-db/ubuntu/$app.config
    done
}

aggregate() {
    for app in $@; do
        echo "Aggregate $app"
        ./aggregate-config.sh ubuntu boot $app
        cd $linuxdir
        make clean
        make -j`nproc` LOCALVERSION=-ubuntu-$app
        INSTALL_PATH=$workdir/compiled-kernels/ubuntu/$app make install
        cd $workdir
        make install-kernel-modules
    done
}
action=$1

shift

$action $@;

