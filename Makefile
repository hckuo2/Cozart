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

build-makefile-db:
	touch filename.db
	cd $(linuxdir) && \
	find -name Makefile | go run ../makefile-extracter.go > ../filename.db


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
	INSTALL_MOD_PATH=../$(mnt)/lib/modules/$(kernelversion)/ make modules_install
	-sudo umount --recursive ../$(mnt)

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
