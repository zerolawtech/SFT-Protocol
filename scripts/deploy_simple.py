#!/usr/bin/python3

from brownie import *

import itertools

def main():
    kyc = accounts[0].deploy(KYCRegistrar, [accounts[0]], 1)
    issuer = accounts[1].deploy(IssuingEntity, [accounts[1]], 1)
    token = accounts[1].deploy(SecurityToken, issuer, "Test Token", "TST", 1000000)
    issuer.addToken(token, {'from': accounts[1]})
    token.modifyTotalSupply(issuer, 1000000, {'from': accounts[1]})
    issuer.setRegistrar(kyc, True, {'from': accounts[1]})
    for count,country,rating in [(c,i[0],i[1]) for c,i in enumerate(itertools.product([1,2,3], [1,2]), start=2)]:
        kyc.addInvestor("investor"+str(count), country, 'aws', rating, 9999999999, [accounts[count]], {'from': accounts[0]})
    issuer.setCountries([1,2,3],[1,1,1],[0,0,0], {'from': accounts[1]})