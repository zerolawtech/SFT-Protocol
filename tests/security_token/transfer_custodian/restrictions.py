#!/usr/bin/python3

from brownie import *
from scripts.deployment import main


def setup():
    main(SecurityToken)
    global token, issuer, cust
    token = SecurityToken[0]
    issuer = IssuingEntity[0]
    cust = OwnedCustodian.deploy(a[0], [a[0]], 1)
    issuer.addCustodian(cust, {'from': a[0]})
    token.mint(issuer, 100000, {'from': a[0]})
    token.transfer(a[2], 1000, {'from': a[0]})
    token.transfer(cust, 500, {'from': a[0]})
    token.transfer(cust, 500, {'from': a[2]})
    issuer.setEntityRestriction(cust.ownerID(), False, {'from': a[0]})


def from_issuer():
    '''restricted custodian - issuer to custodian'''
    check.reverts(
        token.transfer,
        (cust, 1000, {'from': a[0]}),
        "Receiver restricted: Issuer"
    )


def from_investor():
    '''restricted custodian - investor to custodian'''
    check.reverts(
        token.transfer,
        (cust, 1000, {'from': a[2]}),
        "Receiver restricted: Issuer"
    )


def transferInternal():
    '''restricted custodian - internal transfer'''
    check.reverts(
        cust.transferInternal,
        (token, a[2], a[3], 500, {'from': a[0]}),
        "Authority restricted"
    )


def to_issuer():
    '''restricted custodian - to issuer'''
    check.reverts(
        cust.transfer,
        (token, a[0], 500, {'from': a[0]}),
        "Sender restricted: Issuer"
    )


def to_investor():
    '''restricted custodian - to investor'''
    check.reverts(
        cust.transfer,
        (token, a[2], 500, {'from': a[0]}),
        "Sender restricted: Issuer"
    )

def issuer_transferFrom():
    '''restricted custodian - issuer transfer out with transferFrom'''
    token.transferFrom(cust, a[2], 500, {'from': a[0]})