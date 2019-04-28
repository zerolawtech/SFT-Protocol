#!/usr/bin/python3

from brownie import *
from scripts.deployment import main


def setup():
    config['test']['always_transact'] = False
    global kyc, auth_id
    kyc = a[0].deploy(KYCRegistrar, [a[0]], 1)
    kyc.addAuthority((a[-1],a[-2]), [], 1, {'from': a[0]})
    kyc.addInvestor("0x1111", 1, 1, 1, 9999999999, (a[-3],), {'from': a[0]})
    auth_id = kyc.getAuthorityID(a[-1])


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
        (auth_id, 1, 1, 1, 9999999999, (a[1], a[2]), {'from': a[0]}),
        "dev: authority ID"
    )


def add_investor_investor_id():
    '''add investor - known investor ID'''
    check.reverts(
        kyc.addInvestor,
        ("0x1111", 1, 1, 1, 9999999999, (a[3],), {'from': a[0]}),
        "dev: investor ID"
    )


def add_investor_authority_country():
    '''add investor - authority country permission'''
    check.reverts(
        kyc.addInvestor,
        ("0x1234", 1, 1, 1, 9999999999, (a[3],), {'from': a[-1]}),
        "dev: country"
    )
    kyc.setAuthorityCountries(auth_id, (1,), True, {'from': a[0]})
    kyc.addInvestor("0x1234", 1, 1, 1, 9999999999, (a[3],), {'from': a[-1]})
    check.reverts(
        kyc.addInvestor,
        ("0x5678", 2, 1, 1, 9999999999, (a[4],), {'from': a[-1]}),
        "dev: country"
    )
    kyc.setAuthorityCountries(auth_id, (1,), False, {'from': a[0]})
    check.reverts(
        kyc.addInvestor,
        ("0x5678", 1, 1, 1, 9999999999, (a[4],), {'from': a[-1]}),
        "dev: country"
    )


def update_investor():
    '''update investor'''
    check.true(kyc.isRegistered("0x1111"))
    kyc.updateInvestor("0x1111", 2, 4, 1234567890, {'from': a[0]})
    check.true(kyc.isRegistered("0x1111"))
    check.equal(kyc.getInvestor(a[-3])[1:], (False, 4, 1))
    check.equal(kyc.getExpires("0x1111"), 1234567890)
    check.equal(kyc.getRegion("0x1111"), 2)


def update_investor_unknown_id():
    '''update investor - unknown ID'''
    check.reverts(
        kyc.updateInvestor,
        ("0x1234", 1, 1, 9999999999, {'from': a[0]}),
        "dev: country 0"
    )
    check.reverts(
        kyc.updateInvestor,
        (auth_id, 1, 1, 9999999999, {'from': a[0]}),
        "dev: country 0"
    )


def update_investor_rating_zero():
    '''update investor - rating zero'''
    check.reverts(
        kyc.updateInvestor,
        ("0x1111", 1, 0, 9999999999, {'from': a[0]}),
        "dev: rating 0"
    )


def update_investor_authority_country():
    '''update investor - authority country permission'''
    check.reverts(
        kyc.updateInvestor,
        ("0x1111", 1, 1, 9999999999, {'from': a[-1]}),
        "dev: country"
    )
    kyc.setAuthorityCountries(auth_id, (1,), True, {'from': a[0]})
    kyc.updateInvestor("0x1111", 1, 1, 9999999999, {'from': a[-1]}),
    kyc.setAuthorityCountries(auth_id, (1,), False, {'from': a[0]})
    check.reverts(
        kyc.updateInvestor,
        ("0x1111", 1, 1, 9999999999, {'from': a[-1]}),
        "dev: country"
    )


def set_restriction():
    '''set investor restriction'''
    check.true(kyc.isPermittedID("0x1111"))
    kyc.setInvestorRestriction("0x1111", False, {'from': a[0]})
    check.false(kyc.isPermittedID("0x1111"))
    kyc.setInvestorRestriction("0x1111", True, {'from': a[0]})
    check.true(kyc.isPermittedID("0x1111"))

def set_authority():
    '''set investor authority'''
    check.true(kyc.isPermittedID("0x1111"))
    kyc.setAuthorityRestriction(auth_id, False, {'from':a[0]})
    check.true(kyc.isPermittedID("0x1111"))
    kyc.setInvestorAuthority(auth_id, ("0x1111",), {'from': a[0]})
    check.false(kyc.isPermittedID("0x1111"))
    kyc.setInvestorAuthority(kyc.getAuthorityID(a[0]), ("0x1111",), {'from': a[0]})
    check.true(kyc.isPermittedID("0x1111"))


def set_authority_unknown_id():
    '''set investor authority - unknown id'''
    id_ = kyc.getAuthorityID(a[0])
    check.reverts(
        kyc.setInvestorAuthority,
        (id_, (auth_id,), {'from': a[0]}),
        "dev: unknown ID"
    )
    check.reverts(
        kyc.setInvestorAuthority,
        (auth_id, (id_,), {'from': a[0]}),
        "dev: unknown ID"
    )
    check.reverts(
        kyc.setInvestorAuthority,
        (id_, ("0x1234",), {'from': a[0]}),
        "dev: unknown ID"
    )
