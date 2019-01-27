mnt=mnt/
disk=qemu-disk.ext4
setupfile=bench/native/setup_custom.sh
linuxdir="linux-4.19.16"
.PHONY: rm-disk clean

trace-processor: bin/trace-parser

build-directives-db:
	cd $(linuxdir) && \
	../directive-extracter.sh . >> directives.db

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
	INSTALL_MOD_PATH=$(mnt)/lib/modules/4.4.1+/ make modules_install
	-sudo umount --recursive $(mnt)

debootstrap: $(disk) $(mnt)
	sudo mkfs.ext4 $(disk)
	sudo mount -o loop $(disk) $(mnt)
	sudo debootstrap --include="vim kmod time net-tools apache2 apache2-utils" --arch=amd64 --variant=minbase stretch $(mnt)
	sudo umount --recursive $(mnt)

