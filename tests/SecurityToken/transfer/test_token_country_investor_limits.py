#!/usr/bin/python3

import pytest

from brownie import accounts


@pytest.fixture(scope="module", autouse=True)
def setup(approve_many, issuer, token):
    token.mint(issuer, 100000, {'from': accounts[0]})
    issuer.setCountry(1, True, 1, (1, 0, 0, 0, 0, 0, 0, 0), {'from': accounts[0]})
    token.transfer(accounts[1], 1000, {'from': accounts[0]})


def test_country_investor_limit_blocked_issuer_investor(token):
    '''country investor limit - blocked, issuer to investor'''
    with pytest.reverts("Country Investor Limit"):
        token.transfer(accounts[2], 1000, {'from': accounts[0]})


def test_country_investor_limit_blocked_investor_investor(token):
    '''country investor limit - blocked, investor to investor'''
    with pytest.reverts("Country Investor Limit"):
        token.transfer(accounts[2], 500, {'from': accounts[1]})


def test_country_investor_limit_issuer_investor(token):
    '''country investor limit - issuer to existing investor'''
    token.transfer(accounts[1], 1000, {'from': accounts[0]})


def test_country_investor_limit_investor_investor(token):
    '''country investor limit - investor to investor, full balance'''
    token.transfer(accounts[2], 1000, {'from': accounts[1]})


def test_country_investor_limit_investor_investor_different_country(token):
    '''country investor limit, investor to investor, different country'''
    token.transfer(accounts[3], 500, {'from': accounts[1]})


def test_country_investor_limit_rating_blocked_issuer_investor(kyc, issuer, token):
    '''country investor limit, rating - blocked, issuer to investor'''
    issuer.setCountry(1, True, 1, (0, 1, 0, 0, 0, 0, 0, 0), {'from': accounts[0]})
    kyc.updateInvestor(kyc.getID(accounts[2]), 1, 1, 2000000000, {'from': accounts[0]})
    with pytest.reverts("Country Investor Limit: Rating"):
        token.transfer(accounts[2], 1000, {'from': accounts[0]})


def test_country_investor_limit_rating_blocked_investor_investor(kyc, issuer, token):
    '''country investor limit, rating - blocked, investor to investor'''
    issuer.setCountry(1, True, 1, (0, 1, 0, 0, 0, 0, 0, 0), {'from': accounts[0]})
    kyc.updateInvestor(kyc.getID(accounts[2]), 1, 1, 2000000000, {'from': accounts[0]})
    with pytest.reverts("Country Investor Limit: Rating"):
        token.transfer(accounts[2], 500, {'from': accounts[1]})


def test_country_investor_limit_rating_issuer_investor(issuer, token):
    '''country investor limit, rating - issuer to existing investor'''
    issuer.setCountry(1, True, 1, (0, 1, 0, 0, 0, 0, 0, 0), {'from': accounts[0]})
    token.transfer(accounts[1], 1000, {'from': accounts[0]})


def test_country_investor_limit_rating_investor_investor(issuer, token):
    '''country investor limit, rating - investor to investor, full balance'''
    issuer.setCountry(1, True, 1, (0, 1, 0, 0, 0, 0, 0, 0), {'from': accounts[0]})
    token.transfer(accounts[2], 1000, {'from': accounts[1]})


def test_country_investor_limit_rating_investor_investor_different_country(issuer, token):
    '''country investor limit, rating - investor to investor, different rating'''
    issuer.setCountry(1, True, 1, (0, 1, 0, 0, 0, 0, 0, 0), {'from': accounts[0]})
    token.transfer(accounts[2], 500, {'from': accounts[1]})
