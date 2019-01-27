disks=./qemu-disk.ext4;
mnt=./mnt;
for disk in $disks; do
    sudo umount --recursive $mnt;
    sudo mount -o loop $disk $mnt;
    # sudo rsync -avzu --progress -h $@ $mnt;
    sudo cp -r $@ $mnt;
    sudo umount --recursive $mnt;
done

