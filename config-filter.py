#!/usr/bin/env python3
import sys

if __name__ == '__main__':
    base = {}
    for line in open(sys.argv[1]):
        line = line.strip()
        base[line] = True

    for line in open(sys.argv[2]):
        line = line.strip()
        if line not in base:
            print(line)
