#!/usr/bin/python3

import pytest

from brownie import accounts


@pytest.fixture(scope="module", autouse=True)
def setup(id1, id2, issuer, token):
    token.mint(issuer, 100000, {'from': accounts[0]})


def test_issuer_txfrom(token, cust):
    '''Issuer transferFrom custodian'''
    token.transfer(accounts[1], 10000, {'from': accounts[0]})
    token.transfer(cust, 10000, {'from': accounts[1]})
    token.transferFrom(cust, accounts[1], 5000, {'from': accounts[0]})
    assert token.balanceOf(accounts[1]) == 5000
    assert token.balanceOf(cust) == 5000
    assert token.custodianBalanceOf(accounts[1], cust) == 5000


def test_investor_txfrom(token, cust):
    '''Investor transferFrom custodian'''
    token.transfer(accounts[1], 10000, {'from': accounts[0]})
    token.transfer(cust, 10000, {'from': accounts[1]})
    with pytest.reverts("Insufficient allowance"):
        token.transferFrom(cust, accounts[1], 5000, {'from': accounts[1]})
    with pytest.reverts("Insufficient allowance"):
        token.transferFrom(cust, accounts[1], 5000, {'from': accounts[2]})
