# Cozart for Fiasco micro-kernel

## Setup

1. Install dependencies

`apt-get install make gawk g++ binutils pkg-config g++-multilib subversion flex bison xorriso mtools grub-pc-bin`

2. Install source

`make setup-fiasco`

3. Build targets

`make build-allyes build-runtime build-iso`

## Run
`qemu-system-i386 -cdrom hello.iso -nographic`

