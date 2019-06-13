#!/usr/bin/python3

from brownie import *
from scripts.deployment import main


def setup():
    global token, issuer
    token, issuer, _ = main(SecurityToken, (1,2), (1,))


def mint_to_issuer():
    '''mint to issuer'''
    token.mint(issuer, 1000, {'from': a[0]})
    check.equal(token.totalSupply(), 1000)
    check.equal(token.balanceOf(issuer), 1000)
    token.mint(issuer, 2000, {'from': a[0]})
    check.equal(token.totalSupply(), 3000)
    check.equal(token.balanceOf(issuer), 3000)

def mint_to_investors():
    '''mint to investors'''
    token.mint(a[1], 1000, {'from': a[0]})
    check.equal(token.totalSupply(), 1000)
    check.equal(token.balanceOf(a[1]), 1000)
    token.mint(a[2], 2000, {'from': a[0]})
    check.equal(token.totalSupply(), 3000)
    check.equal(token.balanceOf(a[1]), 1000)
    check.equal(token.balanceOf(a[2]), 2000)
    token.mint(a[1], 3000, {'from': a[0]})
    check.equal(token.totalSupply(), 6000)
    check.equal(token.balanceOf(a[1]), 4000)
    check.equal(token.balanceOf(a[2]), 2000)
    token.mint(a[2], 4000, {'from': a[0]})
    check.equal(token.totalSupply(), 10000)
    check.equal(token.balanceOf(a[1]), 4000)
    check.equal(token.balanceOf(a[2]), 6000)

def burn_from_issuer():
    '''burn from issuer'''
    token.mint(issuer, 10000, {'from': a[0]})
    token.burn(issuer, 1000, {'from': a[0]})
    check.equal(token.totalSupply(), 9000)
    check.equal(token.balanceOf(issuer), 9000)
    token.burn(issuer, 4000, {'from': a[0]})
    check.equal(token.totalSupply(), 5000)
    check.equal(token.balanceOf(issuer), 5000)
    token.burn(issuer, 5000, {'from': a[0]})
    check.equal(token.totalSupply(), 0)
    check.equal(token.balanceOf(issuer), 0)

def burn_from_investors():
    '''burn from investors'''
    token.mint(a[1], 5000, {'from': a[0]})
    token.mint(a[2], 10000, {'from': a[0]})
    token.burn(a[1], 2000, {'from': a[0]})
    check.equal(token.totalSupply(), 13000)
    check.equal(token.balanceOf(a[1]), 3000)
    check.equal(token.balanceOf(a[2]), 10000)
    token.burn(a[2], 3000, {'from': a[0]})
    check.equal(token.totalSupply(), 10000)
    check.equal(token.balanceOf(a[1]), 3000)
    check.equal(token.balanceOf(a[2]), 7000)
    token.burn(a[1], 3000, {'from': a[0]})
    check.equal(token.totalSupply(), 7000)
    check.equal(token.balanceOf(a[1]), 0)
    check.equal(token.balanceOf(a[2]), 7000)
    token.burn(a[2], 7000, {'from': a[0]})
    check.equal(token.totalSupply(), 0)
    check.equal(token.balanceOf(a[1]), 0)
    check.equal(token.balanceOf(a[2]), 0)
