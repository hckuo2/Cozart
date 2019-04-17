#!/bin/bash
source lib.sh
tmp=$(mktemp)
printf "%s %s %s %s %s %s %s %s %s %s\n" "type" vmlinux_text vmlinux_data vmlinux_bss vmlinux_dec \
    image_size yes_configs mod_configs total-mod-size loaded-mod-size
for app in $@; do
    dir=$workdir/compiled-kernels/$distro/$app/
    vmlinuz=$dir/vmlinuz*
    config=$dir/config*
    extract-vmlinux $vmlinuz > $tmp
    name=$(basename "$(dirname "$dir")")/$(basename "$dir")
    image_size=$(stat -c %s $vmlinuz)
    binary_info=$(size $tmp | sed '1d' | cut -f1,2,3,4 --output-delimiter=" ")
    yes_count=$(grep '=y' $config | wc | awk '{print $1}')
    mod_count=$(grep '=m' $config | wc | awk '{print $1}')
    total_mod_size=$(find $dir -iname "*.ko" | xargs size | cut -f4 | numsum)
    loaded_mod_size=$total_mod_size
    printf "%s %s %s %s %s %s %s\n" "$name" "$binary_info" "$image_size" \
        "$yes_count" "$mod_count" "$total_mod_size" "$loaded_mod_size"
done

