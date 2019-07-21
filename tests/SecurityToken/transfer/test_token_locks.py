#!/usr/bin/python3

import pytest

from brownie import accounts


@pytest.fixture(scope="module", autouse=True)
def setup(id1, id2, issuer, token):
    token.mint(issuer, 100000, {'from': accounts[0]})


def test_global_lock(issuer, token):
    '''global lock - investor / investor'''
    token.transfer(accounts[1], 1000, {'from': accounts[0]})
    issuer.setGlobalRestriction(True, {'from': accounts[0]})
    with pytest.reverts("Transfers locked: Issuer"):
        token.transfer(accounts[2], 1000, {'from': accounts[1]})
    issuer.setGlobalRestriction(False, {'from': accounts[0]})
    token.transfer(accounts[2], 1000, {'from': accounts[1]})


def test_global_lock_issuer(issuer, token):
    '''global lock - issuer / investor'''
    issuer.setGlobalRestriction(True, {'from': accounts[0]})
    token.transfer(accounts[1], 1000, {'from': accounts[0]})
    with pytest.reverts("Transfers locked: Issuer"):
        token.transfer(accounts[0], 1000, {'from': accounts[1]})
    issuer.setGlobalRestriction(False, {'from': accounts[0]})
    token.transfer(accounts[0], 1000, {'from': accounts[1]})


def test_token_lock(issuer, token):
    '''token lock - investor / investor'''
    token.transfer(accounts[1], 1000, {'from': accounts[0]})
    issuer.setTokenRestriction(token, True, {'from': accounts[0]})
    with pytest.reverts("Transfers locked: Token"):
        token.transfer(accounts[2], 1000, {'from': accounts[1]})
    issuer.setTokenRestriction(token, False, {'from': accounts[0]})
    token.transfer(accounts[2], 1000, {'from': accounts[1]})


def test_token_lock_issuer(issuer, token):
    '''token lock - issuer / investor'''
    issuer.setTokenRestriction(token, True, {'from': accounts[0]})
    token.transfer(accounts[1], 1000, {'from': accounts[0]})
    with pytest.reverts("Transfers locked: Token"):
        token.transfer(accounts[0], 1000, {'from': accounts[1]})
    issuer.setTokenRestriction(token, False, {'from': accounts[0]})
    token.transfer(accounts[0], 1000, {'from': accounts[1]})
