#!/usr/bin/python3

import functools
import pytest

from brownie import accounts


@pytest.fixture(scope="module", autouse=True)
def setup(approve_many, issuer, token):
    token.mint(issuer, 100000, {'from': accounts[0]})


@pytest.fixture(scope="module")
def balance(token, cust):
    yield functools.partial(_check_balance, token, cust)


def _check_balance(token, cust, account, bal, custbal):
    assert token.balanceOf(account) == bal
    assert token.custodianBalanceOf(account, cust) == custbal


def test_into_custodian(balance, token, cust):
    '''Transfer into custodian - investor'''
    token.transfer(accounts[1], 10000, {'from': accounts[0]})
    token.transfer(accounts[2], 10000, {'from': accounts[0]})
    token.transfer(cust, 4000, {'from': accounts[1]})
    token.transfer(cust, 10000, {'from': accounts[2]})
    balance(accounts[1], 6000, 4000)
    balance(accounts[2], 0, 10000)
    assert token.balanceOf(cust) == 14000


def test_cust_internal(balance, token, cust):
    '''Custodian transfer internal - investor to investor'''
    token.transfer(accounts[2], 10000, {'from': accounts[0]})
    token.transfer(cust, 5000, {'from': accounts[2]})
    cust.transferInternal(token, accounts[2], accounts[3], 5000, {'from': accounts[0]})
    balance(accounts[2], 5000, 0)
    balance(accounts[3], 0, 5000)
    assert token.balanceOf(cust) == 5000


def test_cust_out(balance, token, cust):
    '''Transfer out of custodian - investor'''
    token.transfer(accounts[1], 10000, {'from': accounts[0]})
    token.transfer(cust, 10000, {'from': accounts[1]})
    cust.transferInternal(token, accounts[1], accounts[2], 10000, {'from': accounts[0]})
    cust.transfer(token, accounts[2], 10000, {'from': accounts[0]})
    balance(accounts[1], 0, 0)
    balance(accounts[2], 10000, 0)
    assert token.balanceOf(cust) == 0


def test_issuer_cust_in(balance, issuer, token, cust):
    '''Transfers into custodian - issuer'''
    token.transfer(cust, 10000, {'from': accounts[0]})
    balance(accounts[0], 0, 0)
    balance(issuer, 90000, 10000)
    assert token.balanceOf(cust) == 10000
    token.transfer(cust, 90000, {'from': accounts[0]})
    balance(accounts[0], 0, 0)
    balance(issuer, 0, 100000)
    assert token.balanceOf(cust) == 100000


def test_issuer_cust_internal(balance, issuer, token, cust):
    '''Custodian internal transfers - issuer / investor'''
    token.transfer(cust, 10000, {'from': accounts[0]})
    cust.transferInternal(token, issuer, accounts[1], 10000, {'from': accounts[0]})
    balance(accounts[0], 0, 0)
    balance(issuer, 90000, 0)
    balance(accounts[1], 0, 10000)
    assert token.balanceOf(cust) == 10000
    cust.transferInternal(token, accounts[1], issuer, 5000, {'from': accounts[0]})
    balance(accounts[0], 0, 0)
    balance(issuer, 90000, 5000)
    balance(accounts[1], 0, 5000)
    assert token.balanceOf(cust) == 10000
    cust.transferInternal(token, accounts[1], accounts[0], 5000, {'from': accounts[0]})
    balance(accounts[0], 0, 0)
    balance(issuer, 90000, 10000)
    balance(accounts[1], 0, 0)
    assert token.balanceOf(cust) == 10000


def test_issuer_cust_out(balance, issuer, token, cust):
    '''Transfers out of custodian - issuer'''
    token.transfer(cust, 10000, {'from': accounts[0]})
    balance(accounts[0], 0, 0)
    balance(issuer, 90000, 10000)
    assert token.balanceOf(cust) == 10000
    cust.transfer(token, issuer, 3000, {'from': accounts[0]})
    balance(accounts[0], 0, 0)
    balance(issuer, 93000, 7000)
    assert token.balanceOf(cust) == 7000
    cust.transfer(token, accounts[0], 7000, {'from': accounts[0]})
    balance(accounts[0], 0, 0)
    balance(issuer, 100000, 0)
    assert token.balanceOf(cust) == 0
