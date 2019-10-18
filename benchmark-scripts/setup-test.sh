#!/bin/bash
source /benchmark-scripts/general-helper.sh
bootstrap

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

setuptest_mysql_gg() {
    cd $DIR
    rm -rf $DIR/mysql-src
    wget --no-clobber https://github.com/mysql/mysql-server/archive/mysql-5.7.23.tar.gz && tar -zvxf mysql-5.7.23.tar.gz
    mv mysql-server-mysql-5.7.23 mysql-src
    cp mysqlCMakeList.txt mysql-src/CMakeList.txt
    mkdir $DIR/mysql-src/bld
    cd $DIR/mysql-src/bld
    cmake .. -DDOWNLOAD_BOOST=1 -DWITH_BOOST=$DIR/mysql-boost-lib -DWITH_DEBUG=1 -DENABLE_GCOV=ON
    #cmake -E env CFLAGS="-fprofile-arcs -ftest-coverage -pg" CXXFLAGS="-fprofile-arcs -ftest-coverage -pg" LDFLAGS="-fprofile-arcs -ftest-coverage -pg" cmake .. -DDOWNLOAD_BOOST=1 -DWITH_BOOST=$DIR/mysql-boost-lib
    cd /
    # bld/sql/mysqld --initialize
    # mannually copy temp password
    # bld/client/mysqladmin --user=root --password="...." password=root
    # bld/client/mysql -u root -p
    # CREATE DATABASE sbtest;
    # CREATE USER 'sbtest'@'localhost';
    # GRANT ALL PRIVILEGES ON *.* TO 'sbtest'@'localhost';
    # FLUSH PRIVILEGES;
    # quit;
}

setuptest_apache() {
    apt install -y wget libapr1-dev libaprutil1-dev libpcre3-dev libperl-dev bison libtool libwww-perl
    rm -rf $DIR/test-apache
    mkdir -p $DIR/test-apache
    cd $DIR/test-apache
    wget --no-clobber https://www-eu.apache.org/dist//httpd/httpd-2.4.39.tar.gz
    tar -zvxf httpd-2.4.39.tar.gz
    wget --no-clobber https://www-eu.apache.org/dist/perl/mod_perl-2.0.11.tar.gz
    tar -zvxf mod_perl-2.0.11.tar.gz
    cd httpd-2.4.39
    ./configure --prefix=$DIR/test-apache/httpd/prefork --with-mpm=prefork
    make -j`nproc` && make install
    cd $DIR/test-apache
    cd mod_perl-2.0.11
    perl Makefile.PL MP_AP_PREFIX=$DIR/test-apache/httpd/prefork
    make -j`nproc`
    chmod -R 777 $DIR/test-apache
    cd $DIR
}

setuptest_apache_gg() {
    apt install -y wget libapr1-dev libaprutil1-dev libpcre3-dev libperl-dev bison libtool libwww-perl
    rm -rf $DIR/test-apache/
    mkdir -p $DIR/test-apache
    cd $DIR/test-apache
    wget --no-clobber https://www-eu.apache.org/dist//httpd/httpd-2.4.39.tar.gz
    tar -zvxf httpd-2.4.39.tar.gz
    wget --no-clobber https://www-eu.apache.org/dist/perl/mod_perl-2.0.11.tar.gz
    tar -zvxf mod_perl-2.0.11.tar.gz
    cd httpd-2.4.39
    ./configure --prefix=$DIR/test-apache/httpd/prefork --with-mpm=prefork CFLAGS="-fprofile-arcs -ftest-coverage -pg" LDFLAGS="-fprofile-arcs -ftest-coverage -pg" --disable-authn-file --disable-authn-core --disable-authz-host --disable-authz-groupfile  --disable-authz-user --disable-access-compat --disable-auth-basic --disable-reqtimeout --disable-filter --disable-charset-lite --disable-env --disable-headers --disable-setenvif --disable-version --disable-status --disable-autoindex --disable-alias --enable-unixd 
    make -j`nproc` && make install
    cd $DIR/test-apache
    cd mod_perl-2.0.11
    perl Makefile.PL MP_AP_PREFIX=$DIR/test-apache/httpd/prefork
    make -j`nproc`
    chmod -R 777 $DIR/test-apache
    cd $DIR
}

setuptest_php() {
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

setuptest_php_gg() {
    cd $DIR
    apt install -y wget pkg-config libxml2-dev unzip libsqlite3-dev
    rm -rf $DIR/php-src
    wget --no-clobber https://github.com/php/php-src/archive/PHP-7.2.zip
    unzip PHP-7.2
    mv php-src-PHP-7.2 php-src
    cp $DIR/phpMakefile.global $DIR/php-src/
    cp $DIR/php-src/php.ini-production $DIR/php-src/php.ini
    cd $DIR/php-src
    ./buildconf
    ./configure --enable-gcov
    #./configure CFLAGS="-fprofile-arcs -ftest-coverage -pg" LDFLAGS="-fprofile-arcs -ftest-coverage -pg" CXXFLAGS="-fprofile-arcs -ftest-coverage -pg" CPPFLAGS="-fprofile-arcs -ftest-coverage -pg"
    make -j`nproc`
    cd $DIR
}

setuptest_memcached() {
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

setuptest_redis() {
    cd $DIR
    wget --no-clobber https://github.com/antirez/redis/archive/4.0.zip
    unzip 4.0.zip
    mv redis-4.0 redis-src
    cd $DIR/redis-src
    make -j8
}

setuptest_nginx() {
    cd $DIR
    wget --no-clobber https://github.com/nginx/nginx-tests/archive/master.zip
    unzip master.zip
    mv nginx-tests-master nginx-tests
    cd $DIR/nginx-tests
    make -j8
}

setuptest_nginx_gg() {
	apt install libgd-dev
	apt install geoip-bin
	apt install libgeoip-dev
	apt install libxslt-dev
	apt install libssl-dev    
    cd $DIR 
    wget --no-clobber https://github.com/nginx/nginx-tests/archive/master.zip
    unzip master.zip
    mv nginx-tests-master nginx-tests

    wget --no-clobber https://github.com/nginx/nginx/archive/release-1.15.5.tar.gz
    rm -rf $DIR/nginx-src
    tar xzf release-1.15.5.tar.gz
    mv nginx-release-1.15.5 nginx-src
    cd $DIR/nginx-src
    mv auto/configure .
    ./configure --with-cc-opt="-g -O2 -fdebug-prefix-map=/build/nginx-gDK7bF/nginx-1.15.5=. -fstack-protector-strong -Wformat -Werror=format-security -fPIC -Wdate-time -D_FORTIFY_SOURCE=2 --coverage" --with-ld-opt="-Wl,-Bsymbolic-functions -Wl,-z,relro -Wl,-z,now -fPIC --coverage " --prefix=/usr/share/nginx --conf-path=/etc/nginx/nginx.conf --http-log-path=/var/log/nginx/access.log --error-log-path=/var/log/nginx/error.log --lock-path=/var/lock/nginx.lock --pid-path=/run/nginx.pid --modules-path=/usr/lib/nginx/modules --http-client-body-temp-path=/var/lib/nginx/body --http-fastcgi-temp-path=/var/lib/nginx/fastcgi --http-proxy-temp-path=/var/lib/nginx/proxy --http-scgi-temp-path=/var/lib/nginx/scgi --http-uwsgi-temp-path=/var/lib/nginx/uwsgi --with-debug --with-pcre-jit --with-http_ssl_module --with-http_stub_status_module --with-http_realip_module --with-http_auth_request_module --with-http_v2_module --with-http_dav_module --with-http_slice_module --with-threads --with-http_addition_module --with-http_geoip_module=dynamic --with-http_gunzip_module --with-http_gzip_static_module --with-http_image_filter_module=dynamic --with-http_sub_module --with-http_xslt_module=dynamic --with-stream=dynamic --with-stream_ssl_module --with-mail=dynamic --with-mail_ssl_module 
    make -j`nproc`
    sudo make install
}
