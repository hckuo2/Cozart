#!/bin/bash
source /benchmark-scripts/general-helper.sh
bootstrap

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
apache() {
    apt install -y wget libapr1-dev libaprutil1-dev libpcre3-dev libperl-dev bison libtool libwww-perl
    rm -rf $DIR/test-apache
    mkdir -p $DIR/test-apache
    cd $DIR/test-apache
    wget --no-clobber https://www-eu.apache.org/dist//httpd/httpd-2.4.39.tar.gz
    tar -zvxf httpd-2.4.39.tar.gz
    wget --no-clobber https://www-eu.apache.org/dist/perl/mod_perl-2.0.10.tar.gz
    tar -zvxf mod_perl-2.0.10.tar.gz
    cd httpd-2.4.39
    ./configure --prefix=$DIR/test-apache/httpd/prefork --with-mpm=prefork
    make -j`nproc` && make install
    cd $DIR/test-apache
    cd mod_perl-2.0.10
    perl Makefile.PL MP_AP_PREFIX=$DIR/test-apache/httpd/prefork
    make -j`nproc`
    chmod -R 777 $DIR/test-apache
    cd $DIR
}

php() {
    cd $DIR
    apt install -y wget pkg-config libxml2-dev unzip libsqlite3-dev
    rm -rf $DIR/php-src
    wget --no-clobber https://github.com/php/php-src/archive/PHP-7.2.zip
    unzip PHP-7.2
    mv php-src-PHP-7.2 php-src
    cd $DIR/php-src
    ./buildconf
    ./configure
    make -j`nproc`
    cd $DIR
}

memcached() {
    cd $DIR
    apt install -y wget unzip autotools-dev automake libevent-dev
    rm -rf $DIR/memcached-src
    wget --no-clobber https://github.com/memcached/memcached/archive/1.5.16.zip
    unzip 1.5.16.zip
    mv memcached-1.5.16 memcached-src
    cd $DIR/memcached-src
    ./autogen.sh
    ./configure
    make -j`nproc`
    cd $DIR
}

redis() {
    cd $DIR
    wget --no-clobber https://github.com/antirez/redis/archive/4.0.zip
    unzip 4.0.zip
    mv redis-4.0 redis-src
    cd $DIR/redis-src
    make -j8
}
