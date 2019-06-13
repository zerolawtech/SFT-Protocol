#!/usr/bin/python3

from brownie import *
from scripts.deployment import main, deploy_custodian


def setup():
    global token, issuer, cust
    token, issuer, _ = main(SecurityToken, (1,2,3), (1,))
    cust = deploy_custodian()
    token.mint(issuer, 100000, {'from': a[0]})

def zero():
    '''Custodian transfer internal - zero value'''
    token.transfer(a[2], 10000, {'from': a[0]})
    token.transfer(cust, 5000, {'from': a[2]})
    check.reverts(
        cust.transferInternal,
        (token, a[2], a[3], 0, {'from': a[0]}),
        "Cannot send 0 tokens"
    )

def exceed():
    '''Custodian transfer internal - exceed balance'''
    token.transfer(a[2], 10000, {'from': a[0]})
    token.transfer(cust, 5000, {'from': a[2]})
    check.reverts(
        cust.transferInternal,
        (token, a[2], a[3], 6000, {'from': a[0]}),
        "Insufficient Custodial Balance"
    )

def cust_to_cust():
    '''custodian to custodian'''
    cust2 = a[0].deploy(OwnedCustodian, [a[0]], 1)
    issuer.addCustodian(cust2, {'from': a[0]})
    token.transfer(a[2], 10000, {'from': a[0]})
    token.transfer(cust, 5000, {'from': a[2]})
    check.reverts(
        cust.transferInternal,
        (token, a[2], cust2, 500, {'from': a[0]}),
        "Custodian to Custodian"
    )

def mint():
    '''mint to custodian'''
    check.reverts(token.mint, (cust, 1000, {'from': a[0]}))