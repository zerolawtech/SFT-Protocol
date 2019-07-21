#!/usr/bin/python3

import pytest

from brownie import accounts

id_ = "investor1".encode()


def test_add_addresses_known_address(ikyc):
    '''cannot add known addresses'''
    ikyc.addInvestor("0x123456", 1, 1, 1, 9999999999, accounts[5:7], {'from': accounts[0]})
    with pytest.reverts("dev: known address"):
        ikyc.registerAddresses(id_, (accounts[5],), {'from': accounts[0]})
    with pytest.reverts("dev: known address"):
        ikyc.registerAddresses(id_, (accounts[1],), {'from': accounts[0]})
    with pytest.reverts("dev: auth address"):
        ikyc.registerAddresses(id_, (accounts[0],), {'from': accounts[0]})


def test_add_address_repeat(ikyc):
    '''cannot add - repeat addresses'''
    with pytest.reverts("dev: known address"):
        ikyc.registerAddresses(id_, (accounts[5], accounts[6], accounts[5]), {'from': accounts[0]})


def test_restrict_already_restricted(ikyc):
    '''cannot restrict - already restricted'''
    ikyc.restrictAddresses(id_, (accounts[1],), {'from': accounts[0]})
    with pytest.reverts("dev: already restricted"):
        ikyc.restrictAddresses(id_, (accounts[1],), {'from': accounts[0]})


def test_restrict_wrong_ID(ikyc):
    '''cannot restrict - wrong ID'''
    ikyc.addInvestor("0x123456", 1, 1, 1, 9999999999, (accounts[6],), {'from': accounts[0]})
    with pytest.reverts("dev: wrong ID"):
        ikyc.restrictAddresses(id_, (accounts[6],), {'from': accounts[0]})
    with pytest.reverts("dev: wrong ID"):
        ikyc.restrictAddresses("0x123456", (accounts[2],), {'from': accounts[0]})


def test_owner_add_investor_addresses(ikyc):
    '''owner - add investor addresses'''
    ikyc.addInvestor("0x123456", 1, 1, 1, 9999999999, (accounts[5],), {'from': accounts[0]})
    ikyc.registerAddresses("0x123456", (accounts[6], accounts[7]), {'from': accounts[0]})
    assert ikyc.getID(accounts[6]) == "0x123456"
    assert ikyc.getID(accounts[7]) == "0x123456"
