#/usr/bin/env bash
source lib.sh;
find $linuxdir -name Makefile | xargs sed -i -e :a -e '/\\$/N; s/\\\n//; ta'
