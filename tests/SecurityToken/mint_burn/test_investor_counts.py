#!/usr/bin/python3

import pytest

from brownie import accounts



def test_mint_issuer(check_counts, issuer, token):
    '''mint to issuer'''
    token.mint(issuer, 1000, {'from': accounts[0]})
    check_counts()
    token.mint(issuer, 9000, {'from': accounts[0]})
    check_counts()


def test_burn_issuer(check_counts, issuer, token):
    '''burn from issuer'''
    token.mint(issuer, 10000, {'from': accounts[0]})
    token.burn(issuer, 2000, {'from': accounts[0]})
    check_counts()
    token.burn(issuer, 8000, {'from': accounts[0]})
    check_counts()


def test_mint_investors(check_counts, token):
    '''mint to investors'''
    check_counts()
    token.mint(accounts[1], 1000, {'from': accounts[0]})
    check_counts(one=(1, 1, 0))
    token.mint(accounts[1], 1000, {'from': accounts[0]})
    token.mint(accounts[2], 1000, {'from': accounts[0]})
    token.mint(accounts[3], 1000, {'from': accounts[0]})
    check_counts(one=(2, 1, 1), two=(1, 1, 0))
    token.mint(accounts[1], 996000, {'from': accounts[0]})
    check_counts(one=(2, 1, 1), two=(1, 1, 0))


def test_burn_investors(check_counts, token):
    '''burn from investors'''
    token.mint(accounts[1], 5000, {'from': accounts[0]})
    token.mint(accounts[2], 3000, {'from': accounts[0]})
    token.mint(accounts[3], 2000, {'from': accounts[0]})
    token.burn(accounts[1], 1000, {'from': accounts[0]})
    check_counts(one=(2, 1, 1), two=(1, 1, 0))
    token.burn(accounts[1], 4000, {'from': accounts[0]})
    check_counts(one=(1, 0, 1), two=(1, 1, 0))
    token.burn(accounts[2], 3000, {'from': accounts[0]})
    token.burn(accounts[3], 2000, {'from': accounts[0]})
    check_counts()