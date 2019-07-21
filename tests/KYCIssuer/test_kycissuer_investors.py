#!/usr/bin/python3

import pytest

from brownie import accounts

id_ = "investor1".encode()


def test_add_investor(ikyc):
    '''add investor'''
    assert not ikyc.isRegistered("0x1234")
    ikyc.addInvestor("0x1234", 1, 1, 1, 9999999999, (accounts[3],), {'from': accounts[0]})
    assert ikyc.isRegistered("0x1234")
    assert ikyc.getInvestor(accounts[3])[1:] == (True, 1, 1)
    assert ikyc.getExpires("0x1234") == 9999999999


def test_add_investor_country_zero(ikyc):
    '''add investor - country 0'''
    with pytest.reverts("dev: country 0"):
        ikyc.addInvestor(
            "0x1234",
            0,
            1,
            1,
            9999999999,
            (accounts[1], accounts[2]),
            {'from': accounts[0]}
        )


def test_add_investor_rating_zero(ikyc):
    '''add investor - rating 0'''
    with pytest.reverts("dev: rating 0"):
        ikyc.addInvestor(
            "0x1234",
            1,
            1,
            0,
            9999999999,
            (accounts[1], accounts[2]),
            {'from': accounts[0]}
        )


def test_add_investor_authority_id(ikyc, issuer):
    '''add investor - known authority ID'''
    oid = issuer.ownerID()
    with pytest.reverts("dev: authority ID"):
        ikyc.addInvestor(oid, 1, 1, 1, 9999999999, (accounts[2],), {'from': accounts[0]})


def test_add_investor_investor_id(ikyc):
    '''add investor - known investor ID'''
    with pytest.reverts("dev: investor ID"):
        ikyc.addInvestor(id_, 1, 1, 1, 9999999999, (accounts[3],), {'from': accounts[0]})


def test_update_investor(ikyc, token):
    '''update investor'''
    assert ikyc.isRegistered(id_)
    ikyc.updateInvestor(id_, 2, 4, 1234567890, {'from': accounts[0]})
    assert ikyc.isRegistered(id_)
    assert ikyc.getInvestor(accounts[1])[1:] == (False, 4, 1)
    assert ikyc.getExpires(id_) == 1234567890
    assert ikyc.getRegion(id_) == "0x000002"


def test_update_investor_unknown_id(ikyc, issuer):
    '''update investor - unknown ID'''
    oid = issuer.ownerID()
    with pytest.reverts("dev: unknown ID"):
        ikyc.updateInvestor("0x1234", 1, 1, 9999999999, {'from': accounts[0]})
    with pytest.reverts("dev: unknown ID"):
        ikyc.updateInvestor(oid, 1, 1, 9999999999, {'from': accounts[0]})


def test_update_investor_rating_zero(ikyc):
    '''update investor - rating zero'''
    with pytest.reverts("dev: rating 0"):
        ikyc.updateInvestor(id_, 1, 0, 9999999999, {'from': accounts[0]})


def test_set_restriction(ikyc):
    '''set investor restriction'''
    assert ikyc.isPermittedID(id_)
    ikyc.setInvestorRestriction(id_, True, {'from': accounts[0]})
    assert not ikyc.isPermittedID(id_)
    ikyc.setInvestorRestriction(id_, False, {'from': accounts[0]})
    assert ikyc.isPermittedID(id_)
