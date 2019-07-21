#!/usr/bin/python3

import pytest

from brownie import accounts


def test_add_threshold_zero(kyc):
    '''add - zero threshold'''
    with pytest.reverts("dev: zero threshold"):
        kyc.addAuthority((accounts[1],), (1, 2, 3), 0, {'from': accounts[0]})


def test_add_exists_as_investor(kyc, rpc):
    '''add - ID already assigned to investor'''
    kyc.addAuthority((accounts[1],), (1, 2, 3), 1, {'from': accounts[0]})
    id_ = kyc.getAuthorityID(accounts[1])
    rpc.revert()
    kyc.addInvestor(id_, 1, 1, 1, 9999999999, (accounts[1], accounts[2]), {'from': accounts[0]})
    with pytest.reverts("dev: investor ID"):
        kyc.addAuthority((accounts[1],), (1, 2, 3), 1, {'from': accounts[0]})


def test_authority_exists(kyc):
    '''add - authority already exists'''
    kyc.addAuthority((accounts[1],), (1, 2, 3), 1, {'from': accounts[0]})
    with pytest.reverts("dev: authority exists"):
        kyc.addAuthority((accounts[1],), (1, 2, 3), 1, {'from': accounts[0]})


def test_add_threshold_high(kyc):
    '''add - threshold exceed address count'''
    with pytest.reverts("dev: threshold too high"):
        kyc.addAuthority((accounts[1],), (1, 2, 3), 2, {'from': accounts[0]})


def test_add_repeat_address(kyc):
    '''add - repeat address'''
    with pytest.reverts("dev: known address"):
        kyc.addAuthority((accounts[1], accounts[1]), (1, 2, 3), 2, {'from': accounts[0]})


def test_threshold(kyc, auth_id):
    '''set threshold'''
    kyc.setAuthorityThreshold(auth_id, 2, {'from': accounts[0]})
    kyc.setAuthorityThreshold(auth_id, 1, {'from': accounts[0]})


def test_threshold_zero(kyc, auth_id):
    '''set threshold - zero'''
    with pytest.reverts("dev: zero threshold"):
        kyc.setAuthorityThreshold(auth_id, 0, {'from': accounts[0]})


def test_threshold_not_auth(kyc):
    '''set threshold - not an authority'''
    with pytest.reverts("dev: not authority"):
        kyc.setAuthorityThreshold("0x1234", 1, {'from': accounts[0]})


def test_threshold_too_high(kyc, auth_id):
    '''set threshold - too high'''
    with pytest.reverts("dev: threshold too high"):
        kyc.setAuthorityThreshold(auth_id, 3, {'from': accounts[0]})


def test_country(kyc, auth_id):
    '''set countries'''
    countries = (10, 300, 510, 512, 515, 600, 700)
    kyc.setAuthorityCountries(auth_id, countries, True, {'from': accounts[0]})
    for c in countries:
        assert not kyc.isApprovedAuthority(accounts[-1], c - 1)
        assert kyc.isApprovedAuthority(accounts[-1], c)
        assert not kyc.isApprovedAuthority(accounts[-1], c + 1)
    for c in countries:
        kyc.setAuthorityCountries(auth_id, [c], False, {'from': accounts[0]})
        assert not kyc.isApprovedAuthority(accounts[-1], c)


def test_country_not_authority(kyc):
    '''set countries - not an authority'''
    with pytest.reverts("dev: not authority"):
        kyc.setAuthorityCountries("0x1234", (10, 20,), True, {'from': accounts[0]})


def test_restricted(kyc, auth_id):
    '''restrict authority'''
    kyc.setAuthorityCountries(auth_id, (1,), True, {'from': accounts[0]})
    assert kyc.isApprovedAuthority(accounts[-1], 1)
    kyc.setAuthorityRestriction(auth_id, True, {'from': accounts[0]})
    assert not kyc.isApprovedAuthority(accounts[-1], 1)
    kyc.setAuthorityRestriction(auth_id, False, {'from': accounts[0]})
    assert kyc.isApprovedAuthority(accounts[-1], 1)


def test_restricted_not_authority(kyc):
    '''restrict - not authority'''
    with pytest.reverts("dev: not authority"):
        kyc.setAuthorityRestriction("0x1234", False, {'from': accounts[0]})


def test_restricted_owner(kyc):
    '''restrict - owner'''
    with pytest.reverts("dev: owner"):
        kyc.setAuthorityRestriction(kyc.getAuthorityID(accounts[0]), False, {'from': accounts[0]})
