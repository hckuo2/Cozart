#!/bin/bash
source constant.sh
tolower() {
    awk '{print tolower($0)}'
}
i=0
j=0
tmp1=$(mktemp)
for app in Apache Memcached MySQL Nginx PHP Redis; do
    tmp=$(mktemp)
    appname=$(echo $app | tolower)
    cat config-db/$linux/$base/$appname-test.config \
        config-db/$linux/$base/$appname.config | sort -u > $tmp

    comm -13 config-db/$linux/$base/boot.config $tmp \
        | awk -v app=$app -v i=$i '{print i, app, $0}'
    rm $tmp
    ((i++))
done | sort -k3,3 > $tmp1

while read line; do
    cur=$(echo $line | cut -d' ' -f3)
    if [ "$cur" != "$prev" ]; then
        ((j++))
    fi
    echo $line | awk -v j=$j '{print $1, $2,j,$3}'
    prev=$cur
done < $tmp1
rm $tmp1

