# Cozart for Fiasco micro-kernel

## Setup

- Install dependencies
`apt-get install make gawk g++ binutils pkg-config g++-multilib subversion flex bison`

- Build targets
`make build-allyes build-runtime build-iso`

## Run
`qemu-system-i386 -cdrom hello.iso -nographic`

