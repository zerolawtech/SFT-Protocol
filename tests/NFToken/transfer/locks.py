#!/usr/bin/python3

from brownie import *
from scripts.deployment import main


def setup():
    main(NFToken)
    global token, issuer
    token = NFToken[0]
    issuer = IssuingEntity[0]
    token.mint(issuer, 100000, 0, "0x00", {'from': a[0]})


def global_lock():
    '''global lock - investor / investor'''
    token.transfer(a[1], 1000, {'from': a[0]})
    issuer.setGlobalRestriction(False, {'from': a[0]})
    check.reverts(
        token.transfer,
        (a[2], 1000, {'from': a[1]}),
        "Transfers locked: Issuer"
    )
    issuer.setGlobalRestriction(True, {'from': a[0]})
    token.transfer(a[2], 1000, {'from': a[1]})


def global_lock_issuer():
    '''global lock - issuer / investor'''
    issuer.setGlobalRestriction(False, {'from': a[0]})
    token.transfer(a[1], 1000, {'from': a[0]})
    check.reverts(
        token.transfer,
        (a[0], 1000, {'from': a[1]}),
        "Transfers locked: Issuer"
    )
    issuer.setGlobalRestriction(True, {'from': a[0]})
    token.transfer(a[0], 1000, {'from': a[1]})


def token_lock():
    '''token lock - investor / investor'''
    token.transfer(a[1], 1000, {'from': a[0]})
    issuer.setTokenRestriction(token, False, {'from': a[0]})
    check.reverts(
        token.transfer,
        (a[2], 1000, {'from': a[1]}),
        "Transfers locked: Token"
    )
    issuer.setTokenRestriction(token, True, {'from': a[0]})
    token.transfer(a[2], 1000, {'from': a[1]})


def token_lock_issuer():
    '''token lock - issuer / investor'''
    issuer.setTokenRestriction(token, False, {'from': a[0]})
    token.transfer(a[1], 1000, {'from': a[0]})
    check.reverts(
        token.transfer,
        (a[0], 1000, {'from': a[1]}),
        "Transfers locked: Token"
    )
    issuer.setTokenRestriction(token, True, {'from': a[0]})
    token.transfer(a[0], 1000, {'from': a[1]})


def time():
    '''Block transfers with range time lock'''
    token.mint(a[1], 10000, rpc.time() + 20, "0x00", {'from': a[0]})
    check.reverts(
        token.transfer,
        (a[2], 1000, {'from': a[1]})
    )
    rpc.sleep(21)
    token.transfer(a[2], 1000, {'from': a[1]})


def time_partial():
    '''Partially block a transfer with range time lock'''
    token.mint(a[1], 10000, 0, "0x00", {'from': a[0]})
    token.modifyRanges(102001, 106001, rpc.time() + 20, "0x00", {'from': a[0]})
    check.true(token.getRange(102001)['_stop'] == 106001)
    token.transfer(a[2], 4000, {'from': a[1]})
    check.equal(
        token.rangesOf(a[1]),
        ((108001, 110001), (102001, 106001))
    )
    rpc.sleep(25)
    token.transfer(a[2], 6000, {'from': a[1]})
    check.equal(
        token.rangesOf(a[2]),
        ((100001, 110001),)
    )
