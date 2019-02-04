mnt=mnt/
disk=qemu-disk.ext4
setupfile=bench/native/setup_custom.sh
kernelversion=4.19.16
linuxdir=linux-$(kernelversion)
.PHONY: rm-disk clean

trace-processor: bin/trace-parser

build-directives-db:
	cd $(linuxdir) && \
	../directive-extracter.sh . > ../directives.db

ubuntu-bzImage:
	cp ubuntu.config $(linuxdir)/.config;
	cp $(linuxdir) && \
	make olddefconfig && \
	make -j`nproc`

build-makefile-db:
	touch filename.db
	cd $(linuxdir) && \
	find drivers init net -name Makefile | go run ../makefile-extracter.go > ../filename.db

setup-linux:
	wget https://cdn.kernel.org/pub/linux/kernel/v4.x/linux-$(kernelversion).tar.xz
	tar xf linux-$(kernelversion).tar.xz

setup-qemu:
	-git clone --depth 1 -b stable-2.12 https://github.com/qemu/qemu.git
	cd qemu && \
	git submodule init && git submodule update --recursive && \
	git apply -v ../patches/cpu-exec.patch && \
	git apply -v ../patches/trace-events.patch && \
	./configure --enable-trace-backend=log --target-list=x86_64-softmmu && \
	make -j`nproc`

build-ubuntu-vanilla:
	cp -u ubuntu.config $(linuxdir)/.config;
	cd $(linuxdir) && \
	make -j`nproc` bzImage && \
	cp vmlinux ../ubuntu.vmlinux && \
	cp arch/x86/boot/bzImage ../ubuntu.bzImage

bin/%: %.go
	go build -o $@ $<;

$(mnt):
	mkdir -p $(mnt)

$(disk):
	qemu-img create -f raw $(disk) 10G

clean:
	rm -rf ./tmp/* ./bin/*

rm-disk:
	rm $(disk)

install-kernel-modules:
	-sudo umount --recursive $(mnt)
	sudo mount -o loop $(disk) $(mnt)
	cd $(linuxdir) && \
	sudo INSTALL_MOD_PATH=../$(mnt) make modules_install
	-sudo umount --recursive ./$(mnt)

debootstrap: $(disk) $(mnt)
	sudo mkfs.ext4 $(disk)
	sudo mount -o loop $(disk) $(mnt)
	sudo debootstrap --include="vim kmod time net-tools apache2 apache2-utils" --arch=amd64 cosmic $(mnt) http://us.archive.ubuntu.com/ubuntu/
	sudo umount --recursive $(mnt)

ext4-fs:
	cd $(linuxdir); \
	./scripts/config --enable EXT4_FS; \
	./scripts/config --enable BLOCK;

ide-drive:
	cd $(linuxdir); \
	./scripts/config --enable BLOCK; \
	./scripts/config --enable BLK_DEV_SD; \
	./scripts/config --enable ATA_PIIX; \
	./scripts/config --enable ATA; \
	./scripts/config --enable SATA_AHCI; \
	./scripts/config --enable SCSI_CONSTANTS; \
	./scripts/config --enable SCSI_SPI_ATTRS; \

serial:
	cd $(linuxdir); \
	./scripts/config --enable SERIAL_8250; \
	./scripts/config --enable SERIAL_8250_CONSOLE; \

printk:
	cd $(linuxdir); \
	./scripts/config --enable EXPERT; \
	./scripts/config --enable PRINTK;
