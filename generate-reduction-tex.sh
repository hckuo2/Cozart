#!/bin/bash
source constant.sh

init_baseline() {
    local dir="$kernelbuild/$linux/$base/base"
    base_static=$(size $tmp | sed '1d' | cut -f4 --output-delimiter=" ")
    base_lkm=$(find $dir -iname "*.ko" | xargs size | cut -f4 | numsum)
    base_default=5341073
    base_overall=$((base_lkm+base_default))
}
tmp=$(mktemp)
trap "rm $tmp" EXIT
printf "%s %s %s %s %s %s\n" "type" \
    Application yes_configs mod_configs total-mod-size loaded-mod-size

for dir in "$@"; do
    vmlinuz=$(find $dir | grep vmlinuz-)
    config=$(find $dir | grep config-)
    $linux/scripts/extract-vmlinux $vmlinuz > $tmp
    name=$(basename "$(dirname "$dir")")/$(basename "$dir")
    binary_info=$(size $tmp | sed '1d' | cut -f4 --output-delimiter=" ")
    yes_count=$(grep '=y' $config | wc | awk '{print $1}')
    mod_count=$(grep '=m' $config | wc | awk '{print $1}')
    total_mod_size=$(find $dir -iname "*.ko" | xargs size | cut -f4 | numsum)
    loaded_mod_size=$total_mod_size
    printf "%s %s %s %s %s %s\n" "$name" "$binary_info" \
        "$yes_count" "$mod_count" "$total_mod_size" "$loaded_mod_size"
done
