#!/usr/bin/python3

from brownie import *
from scripts.deployment import main


def setup():
    main(NFToken)
    global token, issuer
    token = NFToken[0]
    issuer = IssuingEntity[0]
    token.mint(issuer, 1000000, 0, "0x00", {'from': a[0]})
    issuer.setInvestorLimits([1,0,0,0,0,0,0,0], {'from':a[0]})
    token.transfer(a[1], 1000, {'from': a[0]})


def total_investor_limit_blocked_issuer_investor():
    '''total investor limit - blocked, issuer to investor'''
    check.reverts(
        token.transfer,
        (a[2], 1000, {'from': a[0]}),
        "Total Investor Limit"
    )

def total_investor_limit_blocked_investor_investor():
    '''total investor limit - blocked, investor to investor'''
    check.reverts(
        token.transfer,
        (a[2], 500, {'from': a[1]}),
        "Total Investor Limit"
    )

def total_investor_limit_issuer_investor():
    '''total investor limit - issuer to existing investor'''
    token.transfer(a[1], 1000, {'from': a[0]})

def total_investor_limit_investor_investor():
    '''total investor limit - investor to investor, full balance'''
    token.transfer(a[2], 1000, {'from': a[1]})

def total_investor_limit_rating_blocked_issuer_investor():
    '''total investor limit, rating - blocked, issuer to investor'''
    issuer.setInvestorLimits([0,1,0,0,0,0,0,0], {'from':a[0]})
    check.reverts(
        token.transfer,
        (a[3], 1000, {'from': a[0]}),
        "Total Investor Limit: Rating"
    )

def total_investor_limit_rating_blocked_investor_investor():
    '''total investor limit, rating - blocked, investor to investor'''
    issuer.setInvestorLimits([0,1,0,0,0,0,0,0], {'from':a[0]})
    check.reverts(
        token.transfer,
        (a[3], 500, {'from': a[1]}),
        "Total Investor Limit: Rating"
    )

def total_investor_limit_rating_issuer_investor():
    '''total investor limit, rating - issuer to existing investor'''
    issuer.setInvestorLimits([0,1,0,0,0,0,0,0], {'from':a[0]})
    token.transfer(a[1], 1000, {'from': a[0]})

def total_investor_limit_rating_investor_investor():
    '''total investor limit, rating - investor to investor, full balance'''
    issuer.setInvestorLimits([0,1,0,0,0,0,0,0], {'from':a[0]})
    token.transfer(a[2], 1000, {'from': a[1]})

def total_investor_limit_rating_investor_investor_different_country():
    '''total investor limit, rating - investor to investor, different rating'''
    issuer.setInvestorLimits([0,1,0,0,0,0,0,0], {'from':a[0]})
    token.transfer(a[2], 500, {'from': a[1]})