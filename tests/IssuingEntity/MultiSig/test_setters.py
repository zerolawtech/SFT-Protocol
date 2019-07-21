#!/usr/bin/python3

import pytest

from brownie import accounts


@pytest.fixture(scope="module", autouse=True)
def setup(issuer):
    for i in range(3):
        accounts.add()
        accounts[0].transfer(accounts[-1], "1 ether")
    sigs = (
        issuer.signatures['setAuthoritySignatures'],
        issuer.signatures['setAuthorityApprovedUntil'],
        issuer.signatures['setAuthorityThreshold']
    )
    issuer.addAuthority((accounts[-2],), sigs, 2000000000, 1, {'from': accounts[0]})
    issuer.addAuthority((accounts[-1], accounts[-3]), sigs, 2000000000, 1, {'from': accounts[0]})


@pytest.fixture(scope="module")
def id1(issuer):
    yield issuer.getID(accounts[-2])


@pytest.fixture(scope="module")
def id2(issuer):
    yield issuer.getID(accounts[-1])


def test_set_approval(issuer, id1):
    '''set authrority approved until'''
    issuer.setAuthorityApprovedUntil(id1, 12345, {'from': accounts[0]})
    assert issuer.getAuthority(id1) == (1, 1, 12345)
    issuer.setAuthorityApprovedUntil(id1, 0, {'from': accounts[0]})
    assert issuer.getAuthority(id1) == (1, 1, 0)
    issuer.setAuthorityApprovedUntil(id1, 2000000000, {'from': accounts[0]})
    assert issuer.getAuthority(id1) == (1, 1, 2000000000)


def test_set_approval_as_authority(issuer, id1):
    '''set authority approved until - as authority (reverts)'''
    with pytest.reverts():
        issuer.setAuthorityApprovedUntil(id1, 12345, {'from': accounts[-2]})


def test_set_signatures(issuer, id1):
    '''set authority signatures'''
    sigs = (
        issuer.signatures['addAuthorityAddresses'],
        issuer.signatures['removeAuthorityAddresses']
    )
    assert not issuer.isApprovedAuthority(accounts[-2], sigs[0])
    assert not issuer.isApprovedAuthority(accounts[-2], sigs[1])
    issuer.setAuthoritySignatures(id1, sigs, True, {'from': accounts[0]})
    assert issuer.isApprovedAuthority(accounts[-2], sigs[0])
    assert issuer.isApprovedAuthority(accounts[-2], sigs[1])
    issuer.setAuthoritySignatures(id1, sigs, False, {'from': accounts[0]})
    assert not issuer.isApprovedAuthority(accounts[-2], sigs[0])
    assert not issuer.isApprovedAuthority(accounts[-2], sigs[1])


def test_set_sigs_as_authority(issuer, id1):
    '''set authority signatures - as authority (reverts)'''
    with pytest.reverts():
        issuer.setAuthoritySignatures(
            id1,
            (issuer.signatures['setAuthoritySignatures'],),
            True,
            {'from': accounts[-2]}
        )


def test_set_threshold(issuer, id2):
    '''set threshold'''
    issuer.setAuthorityThreshold(id2, 2, {'from': accounts[0]})
    assert issuer.getAuthority(id2) == (2, 2, 2000000000)
    issuer.setAuthorityThreshold(id2, 1, {'from': accounts[0]})
    assert issuer.getAuthority(id2) == (2, 1, 2000000000)


def test_set_threshold_as_authority(issuer, id2):
    '''set threshold as authority'''
    issuer.setAuthorityThreshold(id2, 2, {'from': accounts[-1]})
    assert issuer.getAuthority(id2) == (2, 2, 2000000000)
    issuer.setAuthorityThreshold(id2, 1, {'from': accounts[-1]})
    assert issuer.getAuthority(id2) == (2, 2, 2000000000)
    issuer.setAuthorityThreshold(id2, 1, {'from': accounts[-3]})
    assert issuer.getAuthority(id2) == (2, 1, 2000000000)


def test_set_threshold_as_authority_not_permitted(issuer, id2):
    '''set threshold as authority, not permitted'''
    issuer.setAuthoritySignatures(
        id2,
        (issuer.signatures['setAuthorityThreshold'],),
        False,
        {'from': accounts[0]}
    )
    with pytest.reverts():
        issuer.setAuthorityThreshold(id2, 2, {'from': accounts[-1]})
    issuer.setAuthoritySignatures(
        id2,
        (issuer.signatures['setAuthorityThreshold'],),
        True,
        {'from': accounts[0]}
    )
    issuer.setAuthorityThreshold(id2, 2, {'from': accounts[-1]})


def test_set_other_authority_threshold(issuer, id1):
    '''set other authority threshold (reverts)'''
    with pytest.reverts("dev: wrong authority"):
        issuer.setAuthorityThreshold(id1, 1, {'from': accounts[-1]})


def test_set_threshold_too_high(issuer, id1):
    '''set threshold too high'''
    with pytest.reverts("dev: threshold too high"):
        issuer.setAuthorityThreshold(id1, 2, {'from': accounts[-2]})
