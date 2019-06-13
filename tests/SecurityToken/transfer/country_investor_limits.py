#!/usr/bin/python3

from brownie import *
from scripts.deployment import main


def setup():
    global token, issuer, kyc
    token, issuer, kyc = main(SecurityToken, (1,2), (1,2))
    token.mint(issuer, 1000000, {'from': a[0]})
    issuer.setCountry(1, True, 1, [1,0,0,0,0,0,0,0], {'from': a[0]})
    token.transfer(a[1], 1000, {'from': a[0]})


def country_investor_limit_blocked_issuer_investor():
    '''country investor limit - blocked, issuer to investor'''
    check.reverts(
        token.transfer,
        (a[2], 1000, {'from': a[0]}),
        "Country Investor Limit"
    )

def country_investor_limit_blocked_investor_investor():
    '''country investor limit - blocked, investor to investor'''
    check.reverts(
        token.transfer,
        (a[2], 500, {'from': a[1]}),
        "Country Investor Limit"
    )

def country_investor_limit_issuer_investor():
    '''country investor limit - issuer to existing investor'''
    token.transfer(a[1], 1000, {'from': a[0]})

def country_investor_limit_investor_investor():
    '''country investor limit - investor to investor, full balance'''
    token.transfer(a[2], 1000, {'from': a[1]})

def country_investor_limit_investor_investor_different_country():
    '''country investor limit, investor to investor, different country'''
    token.transfer(a[3], 500, {'from': a[1]})

def country_investor_limit_rating_blocked_issuer_investor():
    '''country investor limit, rating - blocked, issuer to investor'''
    issuer.setCountry(1, True, 1, [0,1,0,0,0,0,0,0], {'from': a[0]})
    kyc.updateInvestor(kyc.getID(a[2]), 1, 1, 2000000000, {'from': a[0]})
    check.reverts(
        token.transfer,
        (a[2], 1000, {'from': a[0]}),
        "Country Investor Limit: Rating"
    )

def country_investor_limit_rating_blocked_investor_investor():
    '''country investor limit, rating - blocked, investor to investor'''
    issuer.setCountry(1, True, 1, [0,1,0,0,0,0,0,0], {'from': a[0]})
    kyc.updateInvestor(kyc.getID(a[2]), 1, 1, 2000000000, {'from': a[0]})
    check.reverts(
        token.transfer,
        (a[2], 500, {'from': a[1]}),
        "Country Investor Limit: Rating"
    )

def country_investor_limit_rating_issuer_investor():
    '''country investor limit, rating - issuer to existing investor'''
    issuer.setCountry(1, True, 1, [0,1,0,0,0,0,0,0], {'from': a[0]})
    token.transfer(a[1], 1000, {'from': a[0]})

def country_investor_limit_rating_investor_investor():
    '''country investor limit, rating - investor to investor, full balance'''
    issuer.setCountry(1, True, 1, [0,1,0,0,0,0,0,0], {'from': a[0]})
    token.transfer(a[2], 1000, {'from': a[1]})

def country_investor_limit_rating_investor_investor_different_country():
    '''country investor limit, rating - investor to investor, different rating'''
    issuer.setCountry(1, True, 1, [0,1,0,0,0,0,0,0], {'from': a[0]})
    token.transfer(a[2], 500, {'from': a[1]})