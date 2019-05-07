#!/usr/bin/python3

from brownie import *
from scripts.deployment import main


def setup():
    main(NFToken)
    global token, issuer
    token = NFToken[0]
    issuer = IssuingEntity[0]
    token.mint(issuer, 1000000, 0, "0x00", {'from': a[0]})


def issuer_to_investor():
    '''investor counts - issuer/investor transfers'''
    _check_countries()
    token.transfer(a[1], 1000, {'from': a[0]})
    _check_countries(one=(1, 1, 0))
    token.transfer(a[1], 1000, {'from': a[0]})
    token.transfer(a[2], 1000, {'from': a[0]})
    token.transfer(a[3], 1000, {'from': a[0]})
    _check_countries(one=(2, 1, 1), two=(1, 1, 0))
    token.transfer(a[1], 996000, {'from': a[0]})
    _check_countries(one=(2, 1, 1), two=(1, 1, 0))
    token.transfer(a[0], 1000, {'from': a[1]})
    _check_countries(one=(2, 1, 1), two=(1, 1, 0))
    token.transfer(a[0], 997000, {'from': a[1]})
    _check_countries(one=(1, 0, 1), two=(1, 1, 0))
    token.transfer(a[0], 1000, {'from': a[2]})
    token.transfer(a[0], 1000, {'from': a[3]})
    _check_countries()


def investor_to_investor():
    '''investor counts - investor/investor transfers'''
    token.transfer(a[1], 1000, {'from': a[0]})
    token.transfer(a[2], 1000, {'from': a[0]})
    token.transfer(a[3], 1000, {'from': a[0]})
    token.transfer(a[4], 1000, {'from': a[0]})
    token.transfer(a[5], 1000, {'from': a[0]})
    token.transfer(a[6], 1000, {'from': a[0]})
    _check_countries(one=(2, 1, 1), two=(2, 1, 1), three=(2, 1, 1))
    token.transfer(a[2], 500, {'from': a[1]})
    _check_countries(one=(2, 1, 1), two=(2, 1, 1), three=(2, 1, 1))
    token.transfer(a[2], 500, {'from': a[1]})
    _check_countries(one=(1, 0, 1), two=(2, 1, 1), three=(2, 1, 1))
    token.transfer(a[3], 2000, {'from': a[2]})
    _check_countries(two=(2, 1, 1), three=(2, 1, 1))
    token.transfer(a[3], 1000, {'from': a[4]})
    _check_countries(two=(1, 1, 0), three=(2, 1, 1))
    token.transfer(a[4], 500, {'from': a[3]})
    _check_countries(two=(2, 1, 1), three=(2, 1, 1))


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