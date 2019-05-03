#!/usr/bin/python3

import itertools

from brownie import *


def main(token_contract=SecurityToken):
    kyc = accounts[0].deploy(KYCRegistrar, [accounts[0]], 1)
    issuer = accounts[0].deploy(IssuingEntity, [accounts[0]], 1)
    token = accounts[0].deploy(token_contract, issuer, "Test Token", "TST", 1000000)
    issuer.addToken(token, {'from': accounts[0]})
    issuer.setRegistrar(kyc, True, {'from': accounts[0]})

    # Approves accounts[1:7] in KYCRegistrar, with investor ratings 1-2 and country codes 1-3
    product = itertools.product([1, 2, 3], [1, 2])
    for count, country, rating in [(c, i[0], i[1]) for c, i in enumerate(product, start=1)]:
        kyc.addInvestor(
            ("investor" + str(count)).encode(),
            country,
            '0x000001',
            rating,
            9999999999,
            [accounts[count]],
            {'from': accounts[0]}
        )

    # Approves investors from country codes 1-3 in IssuingEntity
    issuer.setCountries(
        [1, 2, 3],
        [1, 1, 1],
        [0, 0, 0],
        {'from': accounts[0]}
    )
