#!/usr/bin/python3

from brownie import *
from scripts.deployment import main


def setup():
    main(NFToken)
    global token, issuer
    token = NFToken[0]
    issuer = IssuingEntity[0]


def mint_issuer():
    '''mint to issuer'''
    token.mint(issuer, 1000, 0, "0x00", {'from': a[0]})
    _check_countries()
    token.mint(issuer, 9000, 0, "0x00",  {'from': a[0]})
    _check_countries()

def burn_issuer():
    '''burn from issuer'''
    token.mint(issuer, 10000, 0, "0x00", {'from': a[0]})
    token.burn(1, 2001, {'from': a[0]})
    _check_countries()
    token.burn(2001, 10001, {'from': a[0]})
    _check_countries()


def mint_investors():
    '''mint to investors'''
    _check_countries()
    token.mint(a[1], 1000, 0, "0x00", {'from': a[0]})
    _check_countries(one=(1, 1, 0))
    token.mint(a[1], 1000, 0, "0x00", {'from': a[0]})
    token.mint(a[2], 1000, 0, "0x00", {'from': a[0]})
    token.mint(a[3], 1000, 0, "0x00", {'from': a[0]})
    _check_countries(one=(2, 1, 1), two=(1, 1, 0))
    token.mint(a[1], 996000, 0, "0x00", {'from': a[0]})
    _check_countries(one=(2, 1, 1), two=(1, 1, 0))

def burn_investors():
    '''burn from investors'''
    token.mint(a[1], 5000, 0, "0x00", {'from': a[0]})
    token.mint(a[2], 3000, 0, "0x00", {'from': a[0]})
    token.mint(a[3], 2000, 0, "0x00", {'from': a[0]})
    token.burn(1, 1001, {'from': a[0]})
    _check_countries(one=(2, 1, 1), two=(1, 1, 0))
    token.burn(1001, 5001, {'from': a[0]})
    _check_countries(one=(1, 0, 1), two=(1, 1, 0))
    token.burn(5001, 8001, {'from': a[0]})
    token.burn(8001, 10001, {'from': a[0]})
    _check_countries()

def _check_countries(one=(0,0,0),two=(0,0,0),three=(0,0,0)):
    check.equal(
        issuer.getInvestorCounts()[0][:3],
        (
            one[0]+two[0]+three[0],
            one[1]+two[1]+three[1],
            one[2]+two[2]+three[2]
        )
    )
    check.equal(issuer.getCountry(1)[1][:3], one)
    check.equal(issuer.getCountry(2)[1][:3], two)
    check.equal(issuer.getCountry(3)[1][:3], three)