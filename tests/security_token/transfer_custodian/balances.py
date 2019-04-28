#!/usr/bin/python3

from brownie import *
from scripts.deployment import main


def setup():
    config['test']['always_transact'] = False
    main(SecurityToken)
    global token, issuer, cust
    token = SecurityToken[0]
    issuer = IssuingEntity[0]
    cust = OwnedCustodian.deploy(a[0], [a[0]], 1)
    issuer.addCustodian(cust, {'from': a[0]})
    token.mint(issuer, 100000, {'from': a[0]})


def into_custodian():
    '''Transfer into custodian - investor'''
    token.transfer(a[1], 10000, {'from': a[0]})
    token.transfer(a[2], 10000, {'from': a[0]})
    token.transfer(cust, 4000, {'from': a[1]})
    token.transfer(cust, 10000, {'from': a[2]})
    check.equal(token.balanceOf(a[1]), 6000)
    check.equal(token.custodianBalanceOf(a[1], cust), 4000)
    check.equal(token.balanceOf(a[2]), 0)
    check.equal(token.custodianBalanceOf(a[2], cust), 10000)
    check.equal(token.balanceOf(cust), 14000)

def cust_internal():
    '''Custodian transfer internal - investor to investor'''
    token.transfer(a[2], 10000, {'from': a[0]})
    token.transfer(cust, 5000, {'from': a[2]})
    cust.transferInternal(token, a[2], a[3], 5000, {'from': a[0]})
    check.equal(token.balanceOf(a[2]), 5000)
    check.equal(token.custodianBalanceOf(a[1], cust), 0)
    check.equal(token.balanceOf(a[3]), 0)
    check.equal(token.custodianBalanceOf(a[3], cust), 5000)
    check.equal(token.balanceOf(cust), 5000)


def cust_out():
    '''Transfer out of custodian - investor'''
    token.transfer(a[1], 10000, {'from': a[0]})
    token.transfer(cust, 10000, {'from': a[1]})
    cust.transferInternal(token, a[1], a[2], 10000, {'from': a[0]})
    cust.transfer(token, a[2], 10000, {'from': a[0]})
    check.equal(token.balanceOf(a[1]), 0)
    check.equal(token.custodianBalanceOf(a[1], cust), 0)
    check.equal(token.balanceOf(a[2]), 10000)
    check.equal(token.custodianBalanceOf(a[2], cust), 0)
    check.equal(token.balanceOf(cust), 0)

def issuer_cust_in():
    '''Transfers into custodian - issuer'''
    token.transfer(cust, 10000, {'from': a[0]})
    check.equal(token.balanceOf(a[0]), 0)
    check.equal(token.custodianBalanceOf(a[0], cust), 0)
    check.equal(token.balanceOf(issuer), 90000)
    check.equal(token.custodianBalanceOf(issuer, cust), 10000)
    check.equal(token.balanceOf(cust), 10000)
    token.transfer(cust, 90000, {'from': a[0]})
    check.equal(token.balanceOf(a[0]), 0)
    check.equal(token.custodianBalanceOf(a[0], cust), 0)
    check.equal(token.balanceOf(issuer), 0)
    check.equal(token.custodianBalanceOf(issuer, cust), 100000)
    check.equal(token.balanceOf(cust), 100000)

def issuer_cust_internal():
    '''Custodian internal transfers - issuer / investor'''
    token.transfer(cust, 10000, {'from': a[0]})
    cust.transferInternal(token, issuer, a[1], 10000, {'from': a[0]})
    check.equal(token.balanceOf(a[0]), 0)
    check.equal(token.custodianBalanceOf(a[0], cust), 0)
    check.equal(token.balanceOf(issuer), 90000)
    check.equal(token.custodianBalanceOf(issuer, cust), 0)
    check.equal(token.balanceOf(a[1]), 0)
    check.equal(token.custodianBalanceOf(a[1], cust), 10000)
    check.equal(token.balanceOf(cust), 10000)
    cust.transferInternal(token, a[1], issuer, 5000, {'from': a[0]})
    check.equal(token.balanceOf(a[0]), 0)
    check.equal(token.custodianBalanceOf(a[0], cust), 0)
    check.equal(token.balanceOf(issuer), 90000)
    check.equal(token.custodianBalanceOf(issuer, cust), 5000)
    check.equal(token.balanceOf(a[1]), 0)
    check.equal(token.custodianBalanceOf(a[1], cust), 5000)
    check.equal(token.balanceOf(cust), 10000)
    cust.transferInternal(token, a[1], a[0], 5000, {'from': a[0]})
    check.equal(token.balanceOf(a[0]), 0)
    check.equal(token.custodianBalanceOf(a[0], cust), 0)
    check.equal(token.balanceOf(issuer), 90000)
    check.equal(token.custodianBalanceOf(issuer, cust), 10000)
    check.equal(token.balanceOf(a[1]), 0)
    check.equal(token.custodianBalanceOf(a[1], cust), 0)
    check.equal(token.balanceOf(cust), 10000)

def issuer_cust_out():
    '''Transfers out of custodian - issuer'''
    token.transfer(cust, 10000, {'from': a[0]})
    check.equal(token.balanceOf(a[0]), 0)
    check.equal(token.custodianBalanceOf(a[0], cust), 0)
    check.equal(token.balanceOf(issuer), 90000)
    check.equal(token.custodianBalanceOf(issuer, cust), 10000)
    check.equal(token.balanceOf(cust), 10000)
    cust.transfer(token, issuer, 3000, {'from': a[0]})
    check.equal(token.balanceOf(a[0]), 0)
    check.equal(token.custodianBalanceOf(a[0], cust), 0)
    check.equal(token.balanceOf(issuer), 93000)
    check.equal(token.custodianBalanceOf(issuer, cust), 7000)
    check.equal(token.balanceOf(cust), 7000)
    cust.transfer(token, a[0], 7000, {'from': a[0]})
    check.equal(token.balanceOf(a[0]), 0)
    check.equal(token.custodianBalanceOf(a[0], cust), 0)
    check.equal(token.balanceOf(issuer), 100000)
    check.equal(token.custodianBalanceOf(issuer, cust), 0)
    check.equal(token.balanceOf(cust), 0)