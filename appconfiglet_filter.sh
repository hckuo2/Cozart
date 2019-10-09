#!/bin/bash
source constant.sh
./classify_config.py | grep sw | cut -d' ' -f1 | ./remove_internal_config.py\
    | ./assign-config-value.py config-db/linux-cosmic/cosmic/base.config | sort

