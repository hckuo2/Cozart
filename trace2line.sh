#!/bin/bash

awk -F "," '{print $1}' | addr2line -e ./fiasco.debug | awk '{print $1}' | sort | uniq
