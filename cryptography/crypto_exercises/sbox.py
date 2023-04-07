#! /usr/bin/env python3

import sys

input_text = sys.argv[1]

# 0000  0
# 0001  1
# 0010  2
# 0011  3
# 0100  4
# 0101  5
# 0110  6
# 0111  7
# 1000  8
# 1001  9
# 1010  A
# 1011  B
# 1100  C
# 1101  D
# 1110  E
# 1111  F

# ==> Shuffle the output values around. <==
sbox = dict()
sbox[0x0] = 0xF
sbox[0x1] = 0xE
sbox[0x2] = 0xD
sbox[0x3] = 0xC
sbox[0x4] = 0xB
sbox[0x5] = 0xA
sbox[0x6] = 0x9
sbox[0x7] = 0x8
sbox[0x8] = 0x7
sbox[0x9] = 0x6
sbox[0xA] = 0x5
sbox[0xB] = 0x4
sbox[0xC] = 0x3
sbox[0xD] = 0x2
sbox[0xE] = 0x1
sbox[0xF] = 0x0

input_bytes = [ord(c) for c in input_text]
output_bytes = []
for b in input_bytes:
    b1 = b >> 4
    b2 = b & 0xF
    c1 = sbox[b1]
    c2 = sbox[b2]
    c = (c1 << 4) + c2
    output_bytes.append(c)

input_hex = [ bin(c) for c in input_bytes ]
output_hex = [ bin(c) for c in output_bytes ]
transformations = zip(input_bytes, input_hex, output_bytes, output_hex)
print('Input\tOutput')
print('-------\t-------')
for pb,ph,cb,ch in transformations:
    pc = chr(pb)
    cc = chr(cb)
    print('{}({})\t{}({})'.format(ph,pc,ch,cc))

