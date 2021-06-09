FROM ubuntu:18.04
RUN apt update && apt install -y gawk python3 python3-pip golang bison \
         build-essential flex bc libelf-dev openssl libssl-dev debootstrap \
         python git pkg-config libglib2.0-dev libpixman-1-dev sudo rsync # kernel/qemu building deps
RUN python3 -m pip install kconfiglib

