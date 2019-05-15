#!/usr/bin/python3

from brownie import *
from scripts.deployment import main


def setup(always_transact=False):
    main(NFToken)
    global token, issuer
    token = NFToken[0]
    issuer = IssuingEntity[0]
    token.mint(issuer, 1000000, 0, "0x00", {'from': accounts[0]})


def simple():
    '''Simple transfer'''
    _transfer(0, 1, 123456)


def no_intersect():
    '''No intersection'''
    _transfer(0, 1, 10)
    _transfer(0, 2, 1000)
    _transfer(0, 3, 10)
    _transfer(2, 4, 50)
    _transfer(2, 4, 900)
    _transfer(2, 4, 49)
    _transfer(2, 4, 1)
    _transfer(4, 2, 1000)
    _totalSupply(5)


def middle():
    '''Intersect on both sides'''
    _transfer(0, 1, 100)
    _transfer(0, 2, 120)
    _transfer(0, 1, 3)
    _transfer(2, 1, 120)
    _totalSupply(3)


def start():
    '''Intersect at start'''
    _transfer(0, 1, 3040)
    _transfer(0, 2, 33)
    _transfer(1, 2, 41)
    _transfer(1, 2, 2999)
    _totalSupply(3)


def stop():
    '''Intersect at end'''
    _transfer(0, 1, 100)
    _transfer(0, 2, 100)
    _transfer(0, 3, 42)
    _transfer(3, 2, 19)
    _transfer(3, 2, 22)
    _transfer(3, 2, 1)
    _totalSupply(4)


def one():
    '''One token'''
    _transfer(0, 1, 1)
    _transfer(0, 2, 1)
    _transfer(0, 3, 1)
    _transfer(0, 4, 1)
    _transfer(0, 5, 1)
    _transfer(1, 4, 1)
    _transfer(2, 3, 1)
    _transfer(5, 4, 1)
    _transfer(3, 4, 2)
    _totalSupply(6)


def split(skip="coverage"):
    '''many ranges'''
    token.modifyAuthorizedSupply("1000 gwei", {'from': accounts[0]})
    token.mint(issuer, "100 gwei", 0, "0x00", {'from': accounts[0]})
    for i in range(2, 7):
        _transfer(0, 1, 12345678)
        _transfer(0, i, 12345678)
        _transfer(0, 1, 12345678)
        _transfer(0, i, 12345678)
    for i in range(6, 1):
        _transfer(1, i, token.balanceOf(a[1]) // 2)
    for i in range(1, 5):
        _transfer(i, 6, token.balanceOf(a[i]))


def _totalSupply(limit):
    b = token.balanceOf(issuer)
    for i in range(limit):
        c = token.balanceOf(a[i])
        b += c
    check.true(token.totalSupply() == b)


def _transfer(from_, to, amount):
    if from_ == 0:
        from_bal = token.balanceOf(issuer)
    else:
        from_bal = token.balanceOf(a[from_])
    if to == 0:
        to_bal = token.balanceOf(issuer)
    else:
        to_bal = token.balanceOf(a[to])
    check.confirms(
        token.transfer,
        (a[to], amount, {'from': a[from_]}),
        "Transfer failed: {} tokens from {} to {}".format(amount, from_, to)
    )
    if from_ == 0 or to == 0:
        return
    check.equal(token.balanceOf(a[from_]), from_bal - amount)
    check.equal(token.balanceOf(a[to]), to_bal + amount)
    check.equal(
        token.balanceOf(a[from_]),
        sum((i[1] - i[0]) for i in token.rangesOf(a[from_]))
    )
    check.equal(
        token.balanceOf(a[to]),
        sum((i[1] - i[0]) for i in token.rangesOf(a[to]))
    )
