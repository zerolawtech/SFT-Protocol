#!/usr/bin/python3

import pytest

from brownie import accounts


@pytest.fixture(scope="module", autouse=True)
def setup(approve_many, issuer, token):
    token.mint(issuer, 100000, {'from': accounts[0]})
    issuer.setInvestorLimits((1, 0, 0, 0, 0, 0, 0, 0), {'from': accounts[0]})
    token.transfer(accounts[1], 1000, {'from': accounts[0]})


@pytest.fixture(scope="module")
def adjust_limits(issuer):
    issuer.setInvestorLimits((0, 1, 0, 0, 0, 0, 0, 0), {'from': accounts[0]})


def test_total_investor_limit_blocked_issuer_investor(token):
    '''total investor limit - blocked, issuer to investor'''
    with pytest.reverts("Total Investor Limit"):
        token.transfer(accounts[2], 1000, {'from': accounts[0]})


def test_total_investor_limit_blocked_investor_investor(token):
    '''total investor limit - blocked, investor to investor'''
    with pytest.reverts("Total Investor Limit"):
        token.transfer(accounts[2], 500, {'from': accounts[1]})


def test_total_investor_limit_issuer_investor(token):
    '''total investor limit - issuer to existing investor'''
    token.transfer(accounts[1], 1000, {'from': accounts[0]})


def test_total_investor_limit_investor_investor(token):
    '''total investor limit - investor to investor, full balance'''
    token.transfer(accounts[2], 1000, {'from': accounts[1]})


def test_total_investor_limit_rating_blocked_issuer_investor(adjust_limits, token):
    '''total investor limit, rating - blocked, issuer to investor'''
    with pytest.reverts("Total Investor Limit: Rating"):
        token.transfer(accounts[3], 1000, {'from': accounts[0]})


def test_total_investor_limit_rating_blocked_investor_investor(token):
    '''total investor limit, rating - blocked, investor to investor'''
    with pytest.reverts("Total Investor Limit: Rating"):
        token.transfer(accounts[3], 500, {'from': accounts[1]})


def test_total_investor_limit_rating_issuer_investor(issuer, token):
    '''total investor limit, rating - issuer to existing investor'''
    token.transfer(accounts[1], 1000, {'from': accounts[0]})


def test_total_investor_limit_rating_investor_investor(issuer, token):
    '''total investor limit, rating - investor to investor, full balance'''
    token.transfer(accounts[2], 1000, {'from': accounts[1]})


def test_total_investor_limit_rating_investor_investor_different_country(token):
    '''total investor limit, rating - investor to investor, different rating'''
    token.transfer(accounts[2], 500, {'from': accounts[1]})
