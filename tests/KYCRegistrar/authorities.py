#!/usr/bin/python3

from brownie import *
from scripts.deployment import main


def setup():
    global kyc, auth_id
    kyc = a[0].deploy(KYCRegistrar, [a[0]], 1)
    kyc.addAuthority((a[-1],a[-2]), [], 1, {'from': a[0]})
    auth_id = kyc.getAuthorityID(a[-1])


def add_threshold_zero():
    '''add - zero threshold'''
    check.reverts(
        kyc.addAuthority,
        ((a[1],), (1,2,3), 0, {'from': a[0]}),
        "dev: zero threshold"
    )


def add_exists_as_investor():
    '''add - ID already assigned to investor'''
    tx = kyc.addAuthority((a[1],), (1,2,3), 1, {'from': a[0]})
    id_ = kyc.getAuthorityID(a[1])
    rpc.revert()
    kyc.addInvestor(id_, 1, 1, 1, 9999999999, (a[1], a[2]), {'from': a[0]})
    check.reverts(
        kyc.addAuthority,
        ((a[1],), (1,2,3), 1, {'from': a[0]}),
        "dev: investor ID"
    )


def authority_exists():
    '''add - authority already exists'''
    kyc.addAuthority((a[1],), (1,2,3), 1, {'from': a[0]})
    check.reverts(
        kyc.addAuthority,
        ((a[1],), (1,2,3), 1, {'from': a[0]}),
        "dev: authority exists"
    )


def add_threshold_high():
    '''add - threshold exceed address count'''
    check.reverts(
        kyc.addAuthority,
        ((a[1],), (1,2,3), 2, {'from': a[0]}),
        "dev: threshold too high"
    )


def add_repeat_address():
    '''add - repeat address'''
    check.reverts(
        kyc.addAuthority,
        ((a[1],a[1]), (1,2,3), 2, {'from': a[0]}),
        "dev: known address"
    )


def threshold():
    '''set threshold'''
    kyc.setAuthorityThreshold(auth_id, 2, {'from': a[0]})
    kyc.setAuthorityThreshold(auth_id, 1, {'from': a[0]})


def threshold_zero():
    '''set threshold - zero'''
    check.reverts(
        kyc.setAuthorityThreshold,
        (auth_id, 0, {'from': a[0]}),
        "dev: zero threshold"
    )


def threshold_not_auth():
    '''set threshold - not an authority'''
    check.reverts(
        kyc.setAuthorityThreshold,
        ("0x1234", 1, {'from': a[0]}),
        "dev: not authority"
    )


def threshold_too_high():
    '''set threshold - too high'''
    check.reverts(
        kyc.setAuthorityThreshold,
        (auth_id, 3, {'from': a[0]}),
        "dev: threshold too high"
    )


def country():
    '''set countries'''
    countries = (10, 300, 510, 512, 515, 600, 700)
    kyc.setAuthorityCountries(auth_id, countries, True, {'from': a[0]})
    for c in countries:
        _check_country(c)
    for c in countries:
        kyc.setAuthorityCountries(auth_id, [c], False, {'from': a[0]})
        check.false(kyc.isApprovedAuthority(a[-1], c))


def country_not_authority():
    '''set countries - not an authority'''
    check.reverts(
        kyc.setAuthorityCountries,
        ("0x1234", (10,20,), True, {'from': a[0]}),
        "dev: not authority"
    )


def restricted():
    '''restrict authority'''
    kyc.setAuthorityCountries(auth_id, (1,), True, {'from': a[0]})
    check.true(kyc.isApprovedAuthority(a[-1], 1))
    kyc.setAuthorityRestriction(auth_id, False, {'from': a[0]})
    check.false(kyc.isApprovedAuthority(a[-1], 1))
    kyc.setAuthorityRestriction(auth_id, True, {'from': a[0]})
    check.true(kyc.isApprovedAuthority(a[-1], 1))


def restricted_not_authority():
    '''restrict - not authority'''
    check.reverts(
        kyc.setAuthorityRestriction,
        ("0x1234", True, {'from': a[0]}),
        "dev: not authority"
    )


def restricted_owner():
    '''restrict - owner'''
    check.reverts(
        kyc.setAuthorityRestriction,
        (kyc.getAuthorityID(a[0]), False, {'from': a[0]}),
        "dev: owner"
    )

def _check_country(country):
    check.false(kyc.isApprovedAuthority(a[-1], country-1))
    check.true(kyc.isApprovedAuthority(a[-1], country))
    check.false(kyc.isApprovedAuthority(a[-1], country+1))
