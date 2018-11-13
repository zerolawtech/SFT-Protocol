#!/usr/bin/python3

import itertools

def deploy():
    kyc = accounts[0].deploy(KYCRegistrar, [accounts[0]], 0)
    issuer = accounts[1].deploy(IssuingEntity, [accounts[1]], 1)
    token = accounts[1].deploy(SecurityToken, issuer.address, "Test Token", "TST", 1000000)
    issuer.addToken(token.address)
    issuer.setRegistrar(kyc.address, True)
    for count,country,rating in [(c,i[0],i[1]) for c,i in enumerate(itertools.product([1,2,3], [1,2]), start=2)]:
        kyc.addInvestor(b"investor"+str(count).encode(), country, 0, rating, 9999999999, [accounts[count]])
    issuer.setCountries([1,2,3],[1,1,1],[0,0,0])