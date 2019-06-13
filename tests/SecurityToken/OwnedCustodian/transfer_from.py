#!/usr/bin/python3

from brownie import *
from scripts.deployment import main, deploy_custodian


def setup():
    global token, issuer, cust
    token, issuer, _ = main(SecurityToken, (1,2), (1,))
    cust = deploy_custodian()
    token.mint(issuer, 100000, {'from': a[0]})


def issuer_txfrom():
    '''Issuer transferFrom custodian'''
    token.transfer(a[1], 10000, {'from': a[0]})
    token.transfer(cust, 10000, {'from': a[1]})
    token.transferFrom(cust, a[1], 5000, {'from': a[0]})
    check.equal(token.balanceOf(a[1]), 5000)
    check.equal(token.balanceOf(cust), 5000)
    check.equal(token.custodianBalanceOf(a[1], cust), 5000)

def investor_txfrom():
    '''Investor transferFrom custodian'''
    token.transfer(a[1], 10000, {'from': a[0]})
    token.transfer(cust, 10000, {'from': a[1]})
    check.reverts(
        token.transferFrom,
        (cust, a[1], 5000, {'from': a[1]}),
        "Insufficient allowance"
    )
    check.reverts(
        token.transferFrom,
        (cust, a[1], 5000, {'from': a[2]}),
        "Insufficient allowance"
    )