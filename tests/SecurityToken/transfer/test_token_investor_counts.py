#!/usr/bin/python3

import pytest

from brownie import accounts


@pytest.fixture(scope="module", autouse=True)
def setup(approve_many, issuer, token):
    token.mint(issuer, 1000000, {'from': accounts[0]})


def test_issuer_to_investor(check_counts, token):
    '''investor counts - issuer/investor transfers'''
    check_counts()
    token.transfer(accounts[1], 1000, {'from': accounts[0]})
    check_counts(one=(1, 1, 0))
    token.transfer(accounts[1], 1000, {'from': accounts[0]})
    token.transfer(accounts[2], 1000, {'from': accounts[0]})
    token.transfer(accounts[3], 1000, {'from': accounts[0]})
    check_counts(one=(2, 1, 1), two=(1, 1, 0))
    token.transfer(accounts[1], 996000, {'from': accounts[0]})
    check_counts(one=(2, 1, 1), two=(1, 1, 0))
    token.transfer(accounts[0], 1000, {'from': accounts[1]})
    check_counts(one=(2, 1, 1), two=(1, 1, 0))
    token.transfer(accounts[0], 997000, {'from': accounts[1]})
    check_counts(one=(1, 0, 1), two=(1, 1, 0))
    token.transfer(accounts[0], 1000, {'from': accounts[2]})
    token.transfer(accounts[0], 1000, {'from': accounts[3]})
    check_counts()


def test_investor_to_investor(check_counts, token):
    '''investor counts - investor/investor transfers'''
    token.transfer(accounts[1], 1000, {'from': accounts[0]})
    token.transfer(accounts[2], 1000, {'from': accounts[0]})
    token.transfer(accounts[3], 1000, {'from': accounts[0]})
    token.transfer(accounts[4], 1000, {'from': accounts[0]})
    token.transfer(accounts[5], 1000, {'from': accounts[0]})
    token.transfer(accounts[6], 1000, {'from': accounts[0]})
    check_counts(one=(2, 1, 1), two=(2, 1, 1), three=(2, 1, 1))
    token.transfer(accounts[2], 500, {'from': accounts[1]})
    check_counts(one=(2, 1, 1), two=(2, 1, 1), three=(2, 1, 1))
    token.transfer(accounts[2], 500, {'from': accounts[1]})
    check_counts(one=(1, 0, 1), two=(2, 1, 1), three=(2, 1, 1))
    token.transfer(accounts[3], 2000, {'from': accounts[2]})
    check_counts(two=(2, 1, 1), three=(2, 1, 1))
    token.transfer(accounts[3], 1000, {'from': accounts[4]})
    check_counts(two=(1, 1, 0), three=(2, 1, 1))
    token.transfer(accounts[4], 500, {'from': accounts[3]})
    check_counts(two=(2, 1, 1), three=(2, 1, 1))
