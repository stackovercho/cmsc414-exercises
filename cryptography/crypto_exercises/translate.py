#! /usr/bin/env python3

import sys

with open(sys.argv[1]) as ciph:
    plain = ciph.readline()
    cipher = ciph.readline()

tr = dict(zip(plain,cipher))
tr[' '] = ' '

output = ''

with open(sys.argv[2]) as inp:
    for line in inp:
        for char in line:
            output += tr[char]

print output

