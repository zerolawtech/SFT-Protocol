#!/usr/bin/python3

import pytest

from brownie import accounts


@pytest.fixture(scope="module", autouse=True)
def setup(issuer, token):
    for i in range(10):
        accounts.add()
    sigs = (
        issuer.signatures['addAuthorityAddresses'],
        issuer.signatures['removeAuthorityAddresses'],
    )
    issuer.addAuthority([accounts[-2]], sigs, 2000000000, 1, {'from': accounts[0]})
    issuer.addAuthority([accounts[-1]], sigs, 2000000000, 1, {'from': accounts[0]})
    accounts[0].transfer(accounts[-2], "1 ether")
    accounts[0].transfer(accounts[-1], "1 ether")


@pytest.fixture(scope="module")
def ownerid(issuer):
    yield issuer.ownerID()


@pytest.fixture(scope="module")
def id1(issuer):
    yield issuer.getID(accounts[-2])


@pytest.fixture(scope="module")
def id2(issuer):
    yield issuer.getID(accounts[-1])


def test_add_addr_owner(issuer, ownerid):
    '''add addresses to owner'''
    issuer.addAuthorityAddresses(ownerid, accounts[-6:-4], {'from': accounts[0]})
    assert issuer.getAuthority(ownerid) == (3, 1, 0)
    issuer.addAuthorityAddresses(ownerid, (accounts[-4],), {'from': accounts[0]})
    assert issuer.getAuthority(ownerid) == (4, 1, 0)


def test_remove_addr_owner(issuer, ownerid):
    '''remove addresses from owner'''
    issuer.addAuthorityAddresses(ownerid, accounts[-10:-5], {'from': accounts[0]})
    issuer.removeAuthorityAddresses(ownerid, accounts[-10:-6], {'from': accounts[0]})
    assert issuer.getAuthority(ownerid) == (2, 1, 0)


def test_add_remove_owner(issuer, ownerid):
    '''add and remove - owner'''
    issuer.addAuthorityAddresses(ownerid, accounts[-10:-5], {'from': accounts[0]})
    issuer.removeAuthorityAddresses(ownerid, accounts[-10:-6], {'from': accounts[0]})
    issuer.addAuthorityAddresses(
        ownerid,
        (accounts[-10], accounts[-9], accounts[-4]),
        {'from': accounts[0]}
    )
    assert issuer.getAuthority(ownerid) == (5, 1, 0)


def test_add_addr_auth(issuer, id1, id2):
    '''add addresses to authorities'''
    issuer.addAuthorityAddresses(id1, accounts[-10:-7], {'from': accounts[0]})
    assert issuer.getAuthority(id1) == (4, 1, 2000000000)
    issuer.addAuthorityAddresses(id1, (accounts[-7],), {'from': accounts[0]})
    assert issuer.getAuthority(id1) == (5, 1, 2000000000)
    issuer.addAuthorityAddresses(id2, accounts[-4:-2], {'from': accounts[0]})
    assert issuer.getAuthority(id2) == (3, 1, 2000000000)


def test_remove_addr_auth(issuer, id1, id2):
    '''remove addresses from authorities'''
    issuer.addAuthorityAddresses(id1, accounts[-10:-7], {'from': accounts[0]})
    issuer.addAuthorityAddresses(id2, accounts[-4:-2], {'from': accounts[0]})
    issuer.removeAuthorityAddresses(id1, accounts[-10:-8], {'from': accounts[0]})
    issuer.removeAuthorityAddresses(id2, accounts[-4:-2], {'from': accounts[0]})
    assert issuer.getAuthority(id1) == (2, 1, 2000000000)
    assert issuer.getAuthority(id2) == (1, 1, 2000000000)


def test_add_remove_auth(issuer, id1, id2):
    '''add and remove - authorities'''
    issuer.addAuthorityAddresses(id1, accounts[-10:-7], {'from': accounts[0]})
    issuer.addAuthorityAddresses(id2, accounts[-7:-5], {'from': accounts[0]})
    issuer.removeAuthorityAddresses(id1, accounts[-10:-8], {'from': accounts[0]})
    issuer.removeAuthorityAddresses(id2, [accounts[-7]], {'from': accounts[0]})
    issuer.addAuthorityAddresses(
        id1,
        (accounts[-10], accounts[-9], accounts[-5]),
        {'from': accounts[0]}
    )
    issuer.addAuthorityAddresses(id2, (accounts[-7], accounts[-4]), {'from': accounts[0]})
    assert issuer.getAuthority(id1) == (5, 1, 2000000000)
    assert issuer.getAuthority(id2) == (4, 1, 2000000000)


def test_add_known(issuer, id1):
    '''add known addresses'''
    issuer.addAuthorityAddresses(id1, accounts[-10:-7], {'from': accounts[0]})
    with pytest.reverts("dev: known address"):
        issuer.addAuthorityAddresses(id1, accounts[-9:-6], {'from': accounts[0]})
    with pytest.reverts("dev: known address"):
        issuer.addAuthorityAddresses(
            id1,
            (accounts[-6], accounts[-5], accounts[-6]),
            {'from': accounts[0]}
        )


def test_add_other(set_countries, issuer, kyc, token, id1):
    '''add already associated address'''
    kyc.addInvestor(
        b'investor1',
        1,
        '0x000001',
        1,
        9999999999,
        (accounts[1],),
        {'from': accounts[0]}
    )
    token.mint(accounts[1], 100, {'from': accounts[0]})
    issuer.addAuthorityAddresses(id1, (accounts[-10],), {'from': accounts[0]})
    with pytest.reverts("dev: known address"):
        issuer.addAuthorityAddresses(id1, (accounts[-10],), {'from': accounts[0]})
    with pytest.reverts("dev: known address"):
        issuer.addAuthorityAddresses(id1, (accounts[1],), {'from': accounts[0]})


def test_remove_below_threshold(issuer, id1, id2):
    '''remove below threshold'''
    issuer.addAuthorityAddresses(id1, accounts[-10:-7], {'from': accounts[0]})
    issuer.setAuthorityThreshold(id1, 3, {'from': accounts[0]})
    with pytest.reverts("dev: count below threshold"):
        issuer.removeAuthorityAddresses(id1, accounts[-10:-7], {'from': accounts[0]})
    issuer.removeAuthorityAddresses(id1, (accounts[-10],), {'from': accounts[0]})
    with pytest.reverts("dev: count below threshold"):
        issuer.removeAuthorityAddresses(id1, accounts[-9:-7], {'from': accounts[0]})
    with pytest.reverts("dev: count below threshold"):
        issuer.removeAuthorityAddresses(id2, (accounts[-1],), {'from': accounts[0]})


def test_remove_unknown_addresses(issuer, id1):
    '''remove unknown addresses'''
    issuer.addAuthorityAddresses(id1, accounts[-10:-8], {'from': accounts[0]})
    with pytest.reverts("dev: wrong ID"):
        issuer.removeAuthorityAddresses(id1, accounts[-10:-6], {'from': accounts[0]})


def test_remove_repeat(issuer, id1):
    '''remove already restricted address'''
    issuer.addAuthorityAddresses(id1, accounts[-10:-8], {'from': accounts[0]})
    with pytest.reverts("dev: already restricted"):
        issuer.removeAuthorityAddresses(
            id1,
            (accounts[-10], accounts[-9], accounts[-10]),
            {'from': accounts[0]}
        )


def test_add_unknown_id(issuer):
    '''add to unknown id'''
    with pytest.reverts("dev: unknown ID"):
        issuer.addAuthorityAddresses("0x1234", accounts[-10:-8], {'from': accounts[0]})


def test_remove_unknown_id(issuer):
    '''remove from unknown id'''
    with pytest.reverts("dev: wrong ID"):
        issuer.removeAuthorityAddresses("0x1234", (accounts[-10],), {'from': accounts[0]})


def test_authority_add_to_self(issuer, id1, id2):
    '''authority - add to self'''
    issuer.addAuthorityAddresses(id1, accounts[-10:-8], {'from': accounts[-2]})
    issuer.addAuthorityAddresses(id2, accounts[-8:-6], {'from': accounts[-1]})


def test_authority_remove_self(issuer, id1, id2):
    '''authority - remove from self'''
    issuer.addAuthorityAddresses(id1, accounts[-10:-8], {'from': accounts[-2]})
    issuer.addAuthorityAddresses(id2, accounts[-8:-6], {'from': accounts[-1]})
    issuer.removeAuthorityAddresses(id1, accounts[-10:-8], {'from': accounts[-2]})
    issuer.removeAuthorityAddresses(id2, (accounts[-8], accounts[-1]), {'from': accounts[-1]})


def test_authority_add_to_other(issuer, id1):
    '''authority - add to other'''
    with pytest.reverts("dev: wrong authority"):
        issuer.addAuthorityAddresses(id1, accounts[-10:-8], {'from': accounts[-1]})


def test_authority_remove_from_other(issuer, id1):
    '''authority - remove from olther'''
    issuer.addAuthorityAddresses(id1, accounts[-10:-8], {'from': accounts[-2]})
    with pytest.reverts("dev: wrong authority"):
        issuer.removeAuthorityAddresses(id1, accounts[-10:-8], {'from': accounts[-1]})
