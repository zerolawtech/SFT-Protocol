#!/usr/bin/python3

from brownie import *


def setup():
    global kyc, issuer, owner_id
    issuer = a[0].deploy(IssuingEntity, (a[0],), 1)
    kyc = a[0].deploy(KYCIssuer, issuer)
    issuer.setRegistrar(kyc, False, {'from': a[0]})
    kyc.addInvestor("0x1111", 1, 1, 1, 9999999999, (a[-3],), {'from': a[0]})
    owner_id = issuer.ownerID()


def add_investor():
    '''add investor'''
    check.false(kyc.isRegistered("0x1234"))
    kyc.addInvestor("0x1234", 1, 1, 1, 9999999999, (a[3],), {'from': a[0]})
    check.true(kyc.isRegistered("0x1234"))
    check.equal(kyc.getInvestor(a[3])[1:], (True, 1, 1))
    check.equal(kyc.getExpires("0x1234"), 9999999999)


def add_investor_country_zero():
    '''add investor - country 0'''
    check.reverts(
        kyc.addInvestor,
        ("0x1234", 0, 1, 1, 9999999999, (a[1], a[2]), {'from': a[0]}),
        "dev: country 0"
    )


def add_investor_rating_zero():
    '''add investor - rating 0'''
    check.reverts(
        kyc.addInvestor,
        ("0x1234", 1, 1, 0, 9999999999, (a[1], a[2]), {'from': a[0]}),
        "dev: rating 0"
    )


def add_investor_authority_id():
    '''add investor - known authority ID'''
    check.reverts(
        kyc.addInvestor,
        (owner_id, 1, 1, 1, 9999999999, (a[1], a[2]), {'from': a[0]}),
        "dev: authority ID"
    )


def add_investor_investor_id():
    '''add investor - known investor ID'''
    check.reverts(
        kyc.addInvestor,
        ("0x1111", 1, 1, 1, 9999999999, (a[3],), {'from': a[0]}),
        "dev: investor ID"
    )


def update_investor():
    '''update investor'''
    check.true(kyc.isRegistered("0x1111"))
    kyc.updateInvestor("0x1111", 2, 4, 1234567890, {'from': a[0]})
    check.true(kyc.isRegistered("0x1111"))
    check.equal(kyc.getInvestor(a[-3])[1:], (False, 4, 1))
    check.equal(kyc.getExpires("0x1111"), 1234567890)
    check.equal(kyc.getRegion("0x1111"), "0x000002")


def update_investor_unknown_id():
    '''update investor - unknown ID'''
    check.reverts(
        kyc.updateInvestor,
        ("0x1234", 1, 1, 9999999999, {'from': a[0]}),
        "dev: unknown ID"
    )
    check.reverts(
        kyc.updateInvestor,
        (owner_id, 1, 1, 9999999999, {'from': a[0]}),
        "dev: unknown ID"
    )


def update_investor_rating_zero():
    '''update investor - rating zero'''
    check.reverts(
        kyc.updateInvestor,
        ("0x1111", 1, 0, 9999999999, {'from': a[0]}),
        "dev: rating 0"
    )



def set_restriction():
    '''set investor restriction'''
    check.true(kyc.isPermittedID("0x1111"))
    kyc.setInvestorRestriction("0x1111", True, {'from': a[0]})
    check.false(kyc.isPermittedID("0x1111"))
    kyc.setInvestorRestriction("0x1111", False, {'from': a[0]})
    check.true(kyc.isPermittedID("0x1111"))