#!/usr/bin/env python3

import sys


def improvement(a, b):
    return (a - b) / b * 100


cur = 0
stats = [0]
for line in sys.stdin:
    line = line.strip()
    if cur == 0:
        stats *= len(line.split(','))
        print(len(stats))
        #  print(line)
    else:
        nums = line.split(',')
        for i in range(len(nums)):
            if nums[i] == '':
                continue
            stats[i] += float(nums[i])
    cur += 1

for i in range(len(stats)):
    stats[i] /= cur
    if i == 0:
        #  print("{:.2f}".format(stats[i]), end="")
        pass
    else:
        #  print(" {:.2f}".format(stats[i]), end="")
        try:
            if i % 2 == 1:
                print(
                    " ({:.2f} %)".format(improvement(stats[i], stats[i - 1])),
                    end="")
        except ZeroDivisionError:
            print(" (empty)", end="")
print()
