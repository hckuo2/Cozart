#!/bin/bash
source constant.sh

CONFIGDIR=config-db/$linux/$base
BOOTCONFIG=$CONFIGDIR/boot.config

for app in $@; do

    diff <(comm -13 $CONFIGDIR/boot.config $CONFIGDIR/$app.config) \
        <(comm -13 $CONFIGDIR/boot.config $CONFIGDIR/$app-test.config)

done
