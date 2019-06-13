#!/usr/bin/python3

import itertools

from brownie import *


def main(token_contract=SecurityToken, countries=(1,2,3), ratings=(1,2)):
    token, issuer, kyc = deploy_contracts(token_contract)
    add_investors(countries, ratings)
    return token, issuer, kyc


def deploy_contracts(token_contract=SecurityToken):
    kyc = accounts[0].deploy(KYCRegistrar, [accounts[0]], 1)
    issuer = accounts[0].deploy(IssuingEntity, [accounts[0]], 1)
    token = accounts[0].deploy(token_contract, issuer, "Test Token", "TST", 1000000)
    issuer.addToken(token, {'from': accounts[0]})
    issuer.setRegistrar(kyc, False, {'from': accounts[0]})
    return token, issuer, kyc


def deploy_custodian():
    accounts[0].deploy(OwnedCustodian, [a[0]], 1)
    IssuingEntity[0].addCustodian(OwnedCustodian[0], {'from': a[0]})
    return OwnedCustodian[0]


def add_investors(countries=(1,2,3), ratings=(1,2)):
    # Approves accounts[1:7] in KYCRegistrar[0], with investor ratings 1-2 and country codes 1-3
    product = itertools.product(countries, ratings)
    for count, country, rating in [(c, i[0], i[1]) for c, i in enumerate(product, start=1)]:
        KYCRegistrar[0].addInvestor(
            ("investor" + str(count)).encode(),
            country,
            '0x000001',
            rating,
            9999999999,
            [accounts[count]],
            {'from': accounts[0]}
        )
    # Approves investors from country codes 1-3 in IssuingEntity[0]
    IssuingEntity[0].setCountries(
        countries,
        [1] * len(countries),
        [0] * len(countries),
        {'from': accounts[0]}
    )
