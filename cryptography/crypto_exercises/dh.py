#! /usr/bin/env python3

import math
import random

# Here's what we need for Diffie-Hellman:
#
#  - a prime number p
#  - a generator g for the group Z*_p
#  - private exponents a and b

# Create a random-number generator.
r = random.Random()

# We need to find a prime modulus.
def find_prime(min_val, max_val):

    # We can define functions within the scope of other functions.
    def is_prime(p):
        if 0 == v % 2:
            return False
        for f in range(3, int(math.sqrt(v))+1, 2):
            if 0 == v % f:
                return False
        return True

    # Loop until we've found a prime.
    while True:
        v = r.randint(min_val,max_val)
        if is_prime(v):
            return(v)

# ==> Change this range! <==
# p = find_prime(11,500)
p = find_prime(110000,5000000)

# g must be relatively prime to p
g = r.randint(3,p-1)

print('p={}, g={}'.format(p,g))

# ==> Alice and Bob must select their exponents a and b <==
a = r.randint(3,p-2)
b = r.randint(3,p-2)

print('a={}, b={}'.format(a,b))

# ==> Now compute the public values A and B that Alice and Bob exchange <==
A = g**a % p
B = g**b % p

print('A={}, B={}'.format(A,B))

# ==> Now compute the shared secret from both Alice's and Bob's perspectives <==
sA = B**a % p
sB = A**b % p

print('sA={}, sB={}'.format(sA,sB))

assert sA == sB

