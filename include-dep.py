#!/usr/bin/env python3
import kconfiglib
import os
import sys
os.environ['srctree'] = "linux-4.19.16"
os.environ['SRCARCH'] = "x86"
os.environ['ARCH'] = "x86"
kconf = kconfiglib.Kconfig()

def _find_deps(dep, result):
    if type(dep) is tuple:
        relation = dep[0]
        if relation == 2 or relation == 20:
            for i in dep[1:]:
                _find_deps(i, result)
    elif type(dep) is kconfiglib.Symbol:
        if dep.name not in result:
            result.add(dep.name)
        else:
            _find_deps(dep.direct_dep, result)


def find_deps(sym):
    result = set()
    _find_deps(sym.direct_dep, result)
    return result


if __name__ == '__main__':
    for line in sys.stdin:
        line = line.strip()
        name = line.replace("CONFIG_", "")
        print("CONFIG_"+name+"=y")
        try:
            for d in find_deps(kconf.syms[name]):
                print("CONFIG_"+d+"=y")
        except KeyError:
            pass

