#!/usr/bin/python3

# this script computes an estimate of your baking and endorsing rights
# on the Tezos network and the relative deposits and rewards.
# The only inputs are p and q.
# p is the ratio of the rolls you own over the rolls active in the system.
# q is the confidence used to compute the "max" rights you may be assigned.

# probability of 1 roll being selected among 30k active rolls
p = 1.0 / 81000
q = 0.9 #confidence

#constants from the protocol (may differ for each network)
preserved_cycles = 5
blocks_per_cycle = 4096
endorsers_per_block = 32

block_security_deposit = 512
endorsement_security_deposit = 64

block_reward = 16
endorsement_reward = 2


from scipy.stats import binom
# https://docs.scipy.org/doc/scipy/reference/generated/scipy.stats.binom.html

def mean_for_n(n):
    mean = p * n
    print(" mean %.2f" % (p * n))
    return mean

def max_for_n(n):
    max = (binom.ppf(q,n,p))
    print(" max  %.2f" % binom.ppf(q,n,p))
    return max

def compute(cycles):
    print("blocks")
    n = blocks_per_cycle * cycles
    bmean = mean_for_n(n)
    bmax = max_for_n(n)

    print("endorsements")
    n = blocks_per_cycle * endorsers_per_block * cycles
    emean = mean_for_n(n)
    emax = max_for_n(n)

    print("deposits")
    print(" mean %.2f + %.2f" % (bmean * block_security_deposit, emean * endorsement_security_deposit))
    print(" max  %.2f + %.2f" % (bmax * block_security_deposit, emax * endorsement_security_deposit))

    print("rewards")
    print(" mean %.2f + %.2f" % (bmean * block_reward, emean * endorsement_reward))
    print(" max  %.2f + %.2f" % (bmax * block_reward, emax * endorsement_reward))


print('prob success %e' % p)
print('confidence   %.2f' % q)
print("----------one-cycle--------------------")
compute(1)
print("----------preserved-cycles-------------")
compute(preserved_cycles)
