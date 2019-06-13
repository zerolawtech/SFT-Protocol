#!/usr/bin/python3

from brownie import *
from scripts.deployment import main


def setup():
    global token, issuer
    token, issuer, _ = main(SecurityToken, (1,2), (1,))
    token.mint(issuer, 1000000, {'from': a[0]})

def zero_tokens():
    '''cannot send 0 tokens'''
    check.reverts(
        token.transfer,
        (a[1], 0, {'from':a[0]}),
        "Cannot send 0 tokens"
    )

def insufficient_balance_investor():
    '''insufficient balance - investor to investor'''
    token.transfer(a[1], 1000, {'from':a[0]})
    check.reverts(
        token.transfer,
        (a[2], 2000, {'from':a[1]}),
        "Insufficient Balance"
    )

def insufficient_balance_issuer():
    '''insufficient balance - issuer to investor'''
    check.reverts(
        token.transfer,
        (a[1], 20000000000, {'from':a[0]}),
        "Insufficient Balance"
    )

def balance():
    '''successful transfer'''
    token.transfer(a[1], 1000, {'from': a[0]})
    check.equal(token.balanceOf(a[1]), 1000)
    token.transfer(a[2], 400, {'from': a[1]})
    check.equal(token.balanceOf(a[1]), 600)
    check.equal(token.balanceOf(a[2]), 400)

def balance_issuer():
    '''issuer balances'''
    check.equal(token.balanceOf(a[0]), 0)
    check.equal(token.balanceOf(issuer), 1000000)
    token.transfer(a[1], 1000, {'from': a[0]})
    check.equal(token.balanceOf(a[0]), 0)
    check.equal(token.balanceOf(issuer), 999000)
    token.transfer(a[0], 1000, {'from': a[1]})
    check.equal(token.balanceOf(a[0]), 0)
    check.equal(token.balanceOf(issuer), 1000000)
    token.transfer(a[1], 1000, {'from': a[0]})
    token.transfer(issuer, 1000, {'from': a[1]})
    check.equal(token.balanceOf(a[0]), 0)
    check.equal(token.balanceOf(issuer), 1000000)

def authority_permission():
    '''issuer subauthority balances'''
    issuer.addAuthority([a[-1]], ["0xa9059cbb"], 2000000000, 1, {'from':a[0]})
    id_ = issuer.getID(a[-1])
    token.transfer(a[1], 1000, {'from': a[-1]})
    check.equal(token.balanceOf(a[0]), 0)
    check.equal(token.balanceOf(a[-1]), 0)
    check.equal(token.balanceOf(issuer), 999000)
    token.transfer(a[-1], 1000, {'from': a[1]})
    check.equal(token.balanceOf(a[0]), 0)
    check.equal(token.balanceOf(a[-1]), 0)
    check.equal(token.balanceOf(issuer), 1000000)