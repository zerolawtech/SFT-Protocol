#!/usr/bin/python3

from brownie import *
from scripts.deployment import main


def setup():
    main(NFToken)
    global token, issuer, cust
    token = NFToken[0]
    issuer = IssuingEntity[0]
    cust = OwnedCustodian.deploy(a[0], [a[0]], 1)
    issuer.addCustodian(cust, {'from': a[0]})
    token.mint(issuer, 100000, 0, "0x00", {'from': a[0]})


def into_custodian():
    '''Transfer into custodian - investor'''
    token.transfer(a[1], 10000, {'from': a[0]})
    token.transfer(a[2], 10000, {'from': a[0]})
    _check_countries(one=(2,1,1))
    token.transfer(cust, 5000, {'from': a[1]})
    _check_countries(one=(2,1,1))
    token.transfer(cust, 10000, {'from': a[2]})
    _check_countries(one=(2,1,1))

def cust_internal():
    '''Custodian transfer internal - investor to investor'''
    token.transfer(a[2], 10000, {'from': a[0]})
    token.transfer(cust, 5000, {'from': a[2]})
    cust.transferInternal(token, a[2], a[3], 5000, {'from': a[0]})
    _check_countries(one=(1,0,1),two=(1,1,0))
    token.transfer(a[3], 5000, {'from': a[0]})
    _check_countries(one=(1,0,1),two=(1,1,0))


def cust_out():
    '''Transfer out of custodian - investor'''
    token.transfer(a[1], 10000, {'from': a[0]})
    token.transfer(cust, 10000, {'from': a[1]})
    cust.transferInternal(token, a[1], a[2], 10000, {'from': a[0]})
    _check_countries(one=(1,0,1))
    cust.transfer(token, a[2], 10000, {'from': a[0]})
    _check_countries(one=(1,0,1))
    token.transfer(issuer, 10000, {'from': a[2]})
    _check_countries()


def issuer_cust_in():
    '''Transfers into custodian - issuer'''
    token.transfer(cust, 10000, {'from': a[0]})
    _check_countries()
    token.transfer(cust, 90000, {'from': a[0]})
    _check_countries()

def issuer_cust_internal():
    '''Custodian internal transfers - issuer / investor'''
    token.transfer(cust, 10000, {'from': a[0]})
    cust.transferInternal(token, issuer, a[1], 10000, {'from': a[0]})
    _check_countries(one=(1,1,0))
    cust.transferInternal(token, a[1], issuer, 5000, {'from': a[0]})
    _check_countries(one=(1,1,0))
    cust.transferInternal(token, a[1], a[0], 5000, {'from': a[0]})
    _check_countries()

def issuer_cust_out():
    '''Transfers out of custodian - issuer'''
    token.transfer(cust, 10000, {'from': a[0]})
    _check_countries()
    cust.transfer(token, issuer, 3000, {'from': a[0]})
    _check_countries()
    cust.transfer(token, a[0], 7000, {'from': a[0]})
    _check_countries()

def _check_countries(one=(0,0,0), two=(0,0,0), three=(0,0,0)):
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