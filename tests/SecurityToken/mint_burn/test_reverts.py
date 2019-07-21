#!/usr/bin/python3

import pytest

from brownie import accounts


def test_mint_zero(issuer, token):
    '''mint 0 tokens'''
    with pytest.reverts("dev: mint 0"):
        token.mint(issuer, 0, {'from': accounts[0]})
    token.mint(issuer, 10000, {'from': accounts[0]})
    with pytest.reverts("dev: mint 0"):
        token.mint(issuer, 0, {'from': accounts[0]})


def test_burn_zero(issuer, token):
    '''burn 0 tokens'''
    with pytest.reverts("dev: burn 0"):
        token.burn(issuer, 0, {'from': accounts[0]})
    token.mint(issuer, 10000, {'from': accounts[0]})
    with pytest.reverts("dev: burn 0"):
        token.burn(issuer, 0, {'from': accounts[0]})


def test_authorized_below_total(issuer, token):
    '''authorized supply below total supply'''
    token.mint(issuer, 100000, {'from': accounts[0]})
    with pytest.reverts("dev: auth below total"):
        token.modifyAuthorizedSupply(10000, {'from': accounts[0]})


def test_total_above_authorized(issuer, token):
    '''total supply above authorized'''
    token.modifyAuthorizedSupply(10000, {'from': accounts[0]})
    with pytest.reverts("dev: exceed auth"):
        token.mint(issuer, 20000, {'from': accounts[0]})
    token.mint(issuer, 6000, {'from': accounts[0]})
    with pytest.reverts("dev: exceed auth"):
        token.mint(issuer, 6000, {'from': accounts[0]})
    token.mint(issuer, 4000, {'from': accounts[0]})
    with pytest.reverts("dev: exceed auth"):
        token.mint(issuer, 1, {'from': accounts[0]})
    with pytest.reverts("dev: mint 0"):
        token.mint(issuer, 0, {'from': accounts[0]})


def test_burn_exceeds_balance(issuer, token):
    '''burn exceeds balance'''
    with pytest.reverts():
        token.burn(issuer, 100, {'from': accounts[0]})
    token.mint(issuer, 4000, {'from': accounts[0]})
    with pytest.reverts():
        token.burn(issuer, 5000, {'from': accounts[0]})
    token.burn(issuer, 3000, {'from': accounts[0]})
    with pytest.reverts():
        token.burn(issuer, 1001, {'from': accounts[0]})
    token.burn(issuer, 1000, {'from': accounts[0]})
    with pytest.reverts():
        token.burn(issuer, 100, {'from': accounts[0]})


def test_mint_to_custodian(issuer, token, cust):
    '''mint to custodian'''
    with pytest.reverts("dev: custodian"):
        token.mint(cust, 6000, {'from': accounts[0]})


def test_burn_from_custodian(issuer, token, cust):
    '''burn from custodian'''
    token.mint(issuer, 10000, {'from': accounts[0]})
    token.transfer(cust, 10000, {'from': accounts[0]})
    with pytest.reverts("dev: custodian"):
        token.burn(cust, 5000, {'from': accounts[0]})


def test_global_lock(issuer, token, id1):
    '''mint - token lock'''
    issuer.setTokenRestriction(token, True, {'from': accounts[0]})
    with pytest.reverts("dev: token locked"):
        token.mint(accounts[1], 1, {'from': accounts[0]})
