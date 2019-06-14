#!/bin/bash
source constant.sh
tmp=$(mktemp)
printf "%s %s %s %s %s %s %s %s %s %s %s\n" "type" \
    configlet vmlinux_text vmlinux_data vmlinux_bss vmlinux_dec \
    image_size yes_configs mod_configs total-mod-size loaded-mod-size
for app in "$@"; do
    dir=$kernelbuild/$linux/$base/$app
    vmlinuz=$(find $dir | grep vmlinuz)
    config=$(find $dir | grep config-)
    $linux/scripts/extract-vmlinux $vmlinuz > $tmp
    name=$(basename "$(dirname "$dir")")/$(basename "$dir")
    if [ -f config-db/$linux/$base/$app.config ]; then
        configlet=$(comm -13 config-db/$linux/$base/boot.config \
            config-db/$linux/$base/$app.config \
            | wc -l)
    else
        configlet=0
    fi
    image_size=$(stat -c %s $vmlinuz)
    binary_info=$(size $tmp | sed '1d' | cut -f1,2,3,4 --output-delimiter=" ")
    yes_count=$(grep '=y' $config | wc | awk '{print $1}')
    mod_count=$(grep '=m' $config | wc | awk '{print $1}')
    total_mod_size=$(find $dir -iname "*.ko" | xargs size | cut -f4 | numsum)
    loaded_mod_size=$total_mod_size
    printf "%s %s %s %s %s %s %s %s\n" "$name" "$configlet" "$binary_info" "$image_size" \
        "$yes_count" "$mod_count" "$total_mod_size" "$loaded_mod_size"
done

