#!/usr/bin/env python3
import sys

def is_constant(str):
    return str != "m" and str != "y" and str != "n"

if __name__ == '__main__':
    # parse the vanilla config file
    vanilla = {}
    with open(sys.argv[1]) as f:
        for line in f:
            line = line.strip()
            if len(line) == 0:
                continue
            if line[0] == "#":
                if "is not set" in line:
                    cols = line.split()
                    print(line)
            else:
                cols = line.split("=")
                if is_constant(cols[1]):
                    print(line)
                else:
                    vanilla[cols[0]] = cols[1]

    with open(sys.argv[2]) as f:
        for line in f:
            conf = line.strip()
            if line[0] == "#":
                continue
            if conf in vanilla:
                print(conf + "=" + vanilla[conf])
