#!/usr/bin/env python3
import sys

def parse_db():
    db = {}
    isnotset = []
    filterfile = sys.argv[1]
    for line in open(filterfile):
        line = line.strip()
        if len(line) == 0:
            continue
        if line[0] == "#":
            if "is not set" in line:
                isnotset.append(line)
            continue
        words = line.split("=")
        if len(words) < 2:
            continue
        db[words[0]] = words[1]
    return db, isnotset

if __name__ == '__main__':
    db, isnotset = parse_db()
    targetfile = sys.argv[2]
    for line in isnotset:
        print(line)
    for line in open(targetfile):
        if line[0] == "#":
            continue
        conf = line.strip()
        if conf in db:
            print(conf+"="+db[conf])

