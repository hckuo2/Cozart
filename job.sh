#!/bin/bash

for app in apache redis docker-hello; do
    ./trace-kernel.sh ubuntu /benchmark-scripts/$app.sh true;
    cp final.config config-db/ubuntu/$app.config
done
