#!/usr/bin/python3

from brownie import *
from scripts.deployment import main


def setup():
    global token, issuer
    token, issuer, _ = main(SecurityToken, (1,2), (1,))
    token.mint(issuer, 1000000, {'from': a[0]})

def global_lock():
    '''global lock - investor / investor'''
    token.transfer(a[1], 1000, {'from': a[0]})
    issuer.setGlobalRestriction(True, {'from': a[0]})
    check.reverts(
        token.transfer,
        (a[2], 1000, {'from': a[1]}),
        "Transfers locked: Issuer"
    )
    issuer.setGlobalRestriction(False, {'from': a[0]})
    token.transfer(a[2], 1000, {'from': a[1]})

def global_lock_issuer():
    '''global lock - issuer / investor'''
    issuer.setGlobalRestriction(True, {'from': a[0]})
    token.transfer(a[1], 1000, {'from': a[0]})
    check.reverts(
        token.transfer,
        (a[0], 1000, {'from': a[1]}),
        "Transfers locked: Issuer"
    )
    issuer.setGlobalRestriction(False, {'from': a[0]})
    token.transfer(a[0], 1000, {'from': a[1]})

def token_lock():
    '''token lock - investor / investor'''
    token.transfer(a[1], 1000, {'from': a[0]})
    issuer.setTokenRestriction(token, True, {'from': a[0]})
    check.reverts(
        token.transfer,
        (a[2], 1000, {'from': a[1]}),
        "Transfers locked: Token"
    )
    issuer.setTokenRestriction(token, False, {'from': a[0]})
    token.transfer(a[2], 1000, {'from': a[1]})

def token_lock_issuer():
    '''token lock - issuer / investor'''
    issuer.setTokenRestriction(token, True, {'from': a[0]})
    token.transfer(a[1], 1000, {'from': a[0]})
    check.reverts(
        token.transfer,
        (a[0], 1000, {'from': a[1]}),
        "Transfers locked: Token"
    )
    issuer.setTokenRestriction(token, False, {'from': a[0]})
    token.transfer(a[0], 1000, {'from': a[1]})