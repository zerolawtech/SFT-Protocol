#!/usr/bin/python3

from brownie import *


def setup():
    global kyc, issuer, owner_id
    issuer = a[0].deploy(IssuingEntity, a[0:3], 1)
    kyc = a[0].deploy(KYCIssuer, issuer)
    issuer.setRegistrar(kyc, False, {'from': a[0]})
    kyc.addInvestor("0x1111", 1, 1, 1, 9999999999, a[3:5], {'from': a[0]})
    owner_id = issuer.ownerID()


def add_addresses_known_address():
    '''cannot add known addresses'''
    kyc.addInvestor("0x123456", 1, 1, 1, 9999999999, a[5:7], {'from': a[0]})
    check.reverts(
        kyc.registerAddresses,
        ("0x1111", (a[5],), {'from':a[0]}),
        "dev: known address"
    )
    check.reverts(
        kyc.registerAddresses,
        ("0x1111", (a[3],), {'from':a[0]}),
        "dev: known address"
    )
    check.reverts(
        kyc.registerAddresses,
        ("0x1111", (a[1],), {'from':a[0]}),
        "dev: auth address"
    )


def add_address_repeat():
    '''cannot add - repeat addresses'''
    check.reverts(
        kyc.registerAddresses,
        ("0x1111", (a[5], a[6], a[5]), {'from':a[0]}),
        "dev: known address"
    )


def restrict_already_restricted():
    '''cannot restrict - already restricted'''
    kyc.restrictAddresses("0x1111", (a[3],), {'from': a[0]})
    check.reverts(
        kyc.restrictAddresses,
        ("0x1111", (a[3],), {'from': a[0]}),
        "dev: already restricted"
    )


def restrict_wrong_ID():
    '''cannot restrict - wrong ID'''
    kyc.addInvestor("0x123456", 1, 1, 1, 9999999999, (a[6],), {'from': a[0]})
    check.reverts(
        kyc.restrictAddresses,
        ("0x1111", (a[6],), {'from': a[0]}),
        "dev: wrong ID"
    )
    check.reverts(
        kyc.restrictAddresses,
        ("0x123456", (a[2],), {'from': a[0]}),
        "dev: wrong ID"
    )


def owner_add_investor_addresses():
    '''owner - add investor addresses'''
    kyc.addInvestor("0x123456", 1, 1, 1, 9999999999, (a[5],), {'from': a[0]})
    kyc.registerAddresses("0x123456", (a[6], a[7]), {'from': a[0]})
    check.equal(kyc.getID(a[6]), "0x123456")
    check.equal(kyc.getID(a[7]), "0x123456")