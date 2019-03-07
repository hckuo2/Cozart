#!/bin/bash
set -e
source lib.sh

trace() {
    for app in apache redis docker-hello; do
        echo "Tracing $app"
        ./trace-kernel.sh ubuntu /benchmark-scripts/$app.sh true;
        cp final.config config-db/ubuntu/$app.config
    done
}

aggregate() {
    for app in apache redis docker-hello; do
        echo "Aggregate $app"
        ./aggregate-config.sh ubuntu $app
        cd $linuxdir
        make -j`nproc` clean
        make -j`nproc` LOCALVERSION=-ubuntu-$app
        INSTALL_PATH=$workdir/compiled-kernels/ubuntu/$app make install
        cd $workdir
    done
}

aggregate;

