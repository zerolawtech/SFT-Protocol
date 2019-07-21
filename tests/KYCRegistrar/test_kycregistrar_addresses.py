#!/usr/bin/python3

import pytest

from brownie import accounts


def test_owner_add_authority_addresses(kyc, owner_id):
    '''add addresses to authority'''
    with pytest.reverts():
        kyc.getAuthorityID(accounts[1])
    with pytest.reverts():
        kyc.getAuthorityID(accounts[2])
    kyc.registerAddresses(owner_id, (accounts[1], accounts[2]), {'from': accounts[0]})
    assert kyc.getAuthorityID(accounts[1]) == owner_id
    assert kyc.getAuthorityID(accounts[2]) == owner_id


def test_owner_restrict_authority_addresses(kyc, owner_id, auth_id):
    '''restrict authority addresses'''
    kyc.registerAddresses(owner_id, (accounts[1], accounts[2]), {'from': accounts[0]})
    kyc.registerAddresses(auth_id, (accounts[3], accounts[4]), {'from': accounts[0]})
    kyc.restrictAddresses(owner_id, (accounts[1], accounts[2]), {'from': accounts[0]})
    kyc.restrictAddresses(auth_id, (accounts[3], accounts[4]), {'from': accounts[0]})
    for i in range(1, 5):
        assert not kyc.isApprovedAuthority(accounts[i], 1)


def test_owner_unrestrict_authority_address(kyc, owner_id, auth_id):
    '''unrestrict authority address es'''
    kyc.registerAddresses(owner_id, (accounts[1], accounts[2]), {'from': accounts[0]})
    kyc.registerAddresses(auth_id, (accounts[3], accounts[4]), {'from': accounts[0]})
    kyc.restrictAddresses(owner_id, (accounts[1], accounts[2]), {'from': accounts[0]})
    kyc.restrictAddresses(auth_id, (accounts[3], accounts[4]), {'from': accounts[0]})
    kyc.registerAddresses(owner_id, (accounts[1],), {'from': accounts[0]})
    kyc.registerAddresses(auth_id, (accounts[3],), {'from': accounts[1]})
    assert kyc.isApprovedAuthority(accounts[1], 1)
    assert not kyc.isApprovedAuthority(accounts[2], 1)
    assert kyc.isApprovedAuthority(accounts[3], 1)
    assert not kyc.isApprovedAuthority(accounts[4], 1)


def test_add_addresses_known_address(kyc, owner_id, auth_id):
    '''cannot add known addresses'''
    kyc.registerAddresses(owner_id, (accounts[1], accounts[2]), {'from': accounts[0]})
    kyc.registerAddresses(auth_id, (accounts[3], accounts[4]), {'from': accounts[0]})
    kyc.addInvestor("0x123456", 1, 1, 1, 9999999999, (accounts[6],), {'from': accounts[0]})
    with pytest.reverts("dev: known address"):
        kyc.registerAddresses(owner_id, (accounts[1], accounts[5]), {'from': accounts[0]})
    with pytest.reverts("dev: known address"):
        kyc.registerAddresses(owner_id, (accounts[3], accounts[5]), {'from': accounts[0]})
    with pytest.reverts("dev: known address"):
        kyc.registerAddresses(owner_id, (accounts[6],), {'from': accounts[0]})

    with pytest.reverts("dev: known address"):
        kyc.registerAddresses(owner_id, (accounts[6],), {'from': accounts[0]})
    with pytest.reverts("dev: known address"):
        kyc.registerAddresses(kyc.getID(accounts[6]), (accounts[3],), {'from': accounts[0]})


def test_add_address_repeat(kyc, owner_id):
    '''cannot add - repeat addresses'''
    with pytest.reverts("dev: known address"):
        kyc.registerAddresses(
            owner_id,
            (accounts[1], accounts[2], accounts[1]),
            {'from': accounts[0]}
        )


def test_restrict_already_restricted(kyc, owner_id, auth_id):
    '''cannot restrict - already restricted'''
    kyc.registerAddresses(owner_id, (accounts[1], accounts[2]), {'from': accounts[0]})
    kyc.registerAddresses(auth_id, (accounts[3], accounts[4]), {'from': accounts[0]})
    kyc.addInvestor("0x123456", 1, 1, 1, 9999999999, (accounts[6],), {'from': accounts[0]})
    kyc.restrictAddresses(owner_id, (accounts[1],), {'from': accounts[0]})
    with pytest.reverts("dev: already restricted"):
        kyc.restrictAddresses(owner_id, (accounts[1],), {'from': accounts[0]})
    kyc.restrictAddresses(auth_id, (accounts[4],), {'from': accounts[0]})
    with pytest.reverts("dev: already restricted"):
        kyc.restrictAddresses(auth_id, (accounts[4],), {'from': accounts[0]})
    kyc.restrictAddresses("0x123456", (accounts[6],), {'from': accounts[0]})
    with pytest.reverts("dev: already restricted"):
        kyc.restrictAddresses("0x123456", (accounts[6],), {'from': accounts[0]})


def test_restrict_wrong_ID(kyc, owner_id, auth_id):
    '''cannot restrict - wrong ID'''
    kyc.registerAddresses(owner_id, (accounts[1], accounts[2]), {'from': accounts[0]})
    kyc.registerAddresses(auth_id, (accounts[3], accounts[4]), {'from': accounts[0]})
    kyc.addInvestor("0x123456", 1, 1, 1, 9999999999, (accounts[6],), {'from': accounts[0]})
    with pytest.reverts("dev: wrong ID"):
        kyc.restrictAddresses(owner_id, (accounts[3],), {'from': accounts[0]})
    with pytest.reverts("dev: wrong ID"):
        kyc.restrictAddresses(owner_id, (accounts[6],), {'from': accounts[0]})
    with pytest.reverts("dev: wrong ID"):
        kyc.restrictAddresses("0x123456", (accounts[1],), {'from': accounts[0]})


def test_remove_address_threshold(kyc, auth_id):
    '''cannot restrict authority addresses - below threshold'''
    kyc.setAuthorityThreshold(auth_id, 2, {'from': accounts[0]})
    with pytest.reverts("dev: below threshold"):
        kyc.restrictAddresses(auth_id, (accounts[-1],), {'from': accounts[0]})


def test_authority_add_authority_addresses(kyc, owner_id, auth_id):
    '''authority cannot add authority addresses'''
    with pytest.reverts("dev: not owner"):
        kyc.registerAddresses(owner_id, (accounts[1], accounts[2]), {'from': accounts[-1]})
    with pytest.reverts("dev: not owner"):
        kyc.registerAddresses(auth_id, (accounts[1], accounts[2]), {'from': accounts[-1]})


def test_authority_restrict_authority_addresses(kyc, owner_id, auth_id):
    '''authority cannot restrict authority addresses'''
    kyc.registerAddresses(owner_id, (accounts[1], accounts[2]), {'from': accounts[0]})
    kyc.registerAddresses(auth_id, (accounts[3], accounts[4]), {'from': accounts[0]})
    with pytest.reverts("dev: not owner"):
        kyc.restrictAddresses(owner_id, (accounts[1], accounts[2]), {'from': accounts[-1]})
    with pytest.reverts("dev: not owner"):
        kyc.restrictAddresses(auth_id, (accounts[3], accounts[4]), {'from': accounts[-1]})


def test_owner_add_investor_addresses(kyc):
    '''owner - add investor addresses'''
    kyc.addInvestor("0x123456", 1, 1, 1, 9999999999, (accounts[1],), {'from': accounts[0]})
    kyc.registerAddresses("0x123456", (accounts[2], accounts[3]), {'from': accounts[0]})
    assert kyc.getID(accounts[2]) == "0x123456"
    assert kyc.getID(accounts[3]) == "0x123456"


def test_authority_add_investor_addresses(kyc):
    '''authority - add investor addresses'''
    kyc.addInvestor("0x123456", 1, 1, 1, 9999999999, (accounts[1],), {'from': accounts[-1]})
    kyc.registerAddresses("0x123456", (accounts[2], accounts[3]), {'from': accounts[-1]})
    assert kyc.getID(accounts[2]) == "0x123456"
    assert kyc.getID(accounts[3]) == "0x123456"


def test_authority_add_addresses_not_permitted_country(kyc, auth_id):
    '''authority - add investor addresses - not permitted country'''
    kyc.addInvestor("0x123456", 2, 1, 1, 9999999999, (accounts[1],), {'from': accounts[0]})
    with pytest.reverts("dev: country"):
        kyc.registerAddresses("0x123456", (accounts[2],), {'from': accounts[-1]})
    kyc.setAuthorityCountries(auth_id, (2,), True, {'from': accounts[0]})
    kyc.registerAddresses("0x123456", (accounts[2],), {'from': accounts[-1]})


def test_authority_restrict_addresses_not_permitted_country(kyc, auth_id):
    '''authority - restrict investor addresses - not permitted country'''
    kyc.addInvestor(
        "0x123456",
        2,
        1,
        1,
        9999999999,
        (accounts[1], accounts[2]),
        {'from': accounts[0]}
    )
    with pytest.reverts("dev: country"):
        kyc.restrictAddresses("0x123456", (accounts[1],), {'from': accounts[-1]})
    kyc.setAuthorityCountries(auth_id, (2,), True, {'from': accounts[0]})
    kyc.restrictAddresses("0x123456", (accounts[1],), {'from': accounts[-1]})
