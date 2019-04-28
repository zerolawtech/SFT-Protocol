from brownie import *
from scripts.deployment import main


def setup():
    config['test']['always_transact'] = False
    config['test']['default_contract_owner'] = True
    main(NFToken)
    global token, issuer
    token = NFToken[0]
    issuer = IssuingEntity[0]


def mint_no_merge_owner():
    '''Mint and do not merge - different owners'''
    token.mint(a[1], 10000, 0, "0x00")
    token.mint(a[2], 5000, 0, "0x00")
    check.equal(token.totalSupply(), 15000)
    check.equal(token.balanceOf(a[1]), 10000)
    check.equal(token.balanceOf(a[2]), 5000)
    check.equal(
        token.rangesOf(a[1]),
        ((1, 10001), )
    )
    check.equal(
        token.rangesOf(a[2]),
        ((10001, 15001), )
    )


def mint_no_merge_tag():
    '''Mint and do not merge - different tags'''
    token.mint(a[1], 10000, 0, "0x00")
    token.mint(a[1], 5000, 0, "0x01")
    check.equal(token.totalSupply(), 15000)
    check.equal(
        token.rangesOf(a[1]),
        ((1, 10001), (10001, 15001))
    )
    check.equal(token.balanceOf(a[1]), 15000)


def mint_merge():
    '''Mint and merge range'''
    token.mint(a[1], 10000, 0, "0x00")
    token.mint(a[1], 5000, 0, "0x00")
    check.equal(token.totalSupply(), 15000)
    check.equal(token.rangesOf(a[1]), ((1, 15001), ))
    check.equal(token.balanceOf(a[1]), 15000)


def burn_range():
    '''Burn range'''
    token.mint(a[1], 10000, 0, "0x00")
    token.mint(a[2], 5000, 0, "0x00")
    token.mint(a[1], 5000, 0, "0x00")
    check.equal(token.totalSupply(), 20000)
    check.equal(
        token.rangesOf(a[1]),
        ((1, 10001), (15001, 20001))
    )
    check.equal(
        token.rangesOf(a[2]),
        ((10001, 15001), )
    )
    token.burn(10001, 15001)
    check.equal(token.totalSupply(), 15000)
    check.equal(
        token.rangesOf(a[1]),
        ((1, 10001), (15001, 20001))
    )
    check.equal(token.rangesOf(a[2]), ())
    check.equal(token.balanceOf(a[2]), 0)


def burn_all():
    '''Burn total supply'''
    token.mint(a[1], 10000, 0, "0x00")
    token.burn(1, 10001)
    check.equal(token.totalSupply(), 0)
    check.equal(token.balanceOf(a[1]), 0)
    check.equal(token.rangesOf(a[1]), ())


def burn_inside():
    '''Burn inside'''
    token.mint(a[1], 10000, 0, "0x00")
    token.burn(2000, 4000)
    check.equal(token.totalSupply(), 8000)
    check.equal(token.balanceOf(a[1]), 8000)
    check.equal(
        token.rangesOf(a[1]),
        ((1, 2000), (4000, 10001))
    )


def burn_left():
    '''Burn left'''
    token.mint(a[2], 1000, 0, "0x00")
    token.mint(a[1], 9000, 0, "0x00")
    token.burn(1001, 5001)
    check.equal(token.totalSupply(), 6000)
    check.equal(
        token.rangesOf(a[1]),
        ((5001, 10001),)
    )


def burn_right():
    '''Burn right'''
    token.mint(a[1], 9000, 0, "0x00")
    token.mint(a[2], 1000, 0, "0x00")
    token.burn(5001, 9001)
    check.equal(token.totalSupply(), 6000)
    check.equal(
        token.rangesOf(a[1]),
        ((1, 5001),)
    )


def burn_abs_left():
    '''Burn absolute left'''
    token.mint(a[1], 10000, 0, "0x00")
    token.burn(1, 5001)
    check.equal(token.totalSupply(), 5000)
    check.equal(
        token.rangesOf(a[1]),
        ((5001, 10001),)
    )


def burn_abs_right():
    '''Burn absolute right'''
    token.mint(a[1], 10000, 0, "0x00")
    token.burn(5001, 10001)
    check.equal(token.totalSupply(), 5000)
    check.equal(
        token.rangesOf(a[1]),
        ((1, 5001),)
    )
