#!/usr/bin/python3

from brownie import *
from scripts.deployment import main


def setup():
    main(SecurityToken)
    global token, issuer, kyc
    token = SecurityToken[0]
    issuer = IssuingEntity[0]
    kyc = KYCRegistrar[0]
    token.mint(issuer, 1000000, {'from': a[0]})
    token.transfer(a[1], 1000, {'from': a[0]})

def transfer_from():
    '''investor transferFrom - approved'''
    token.approve(a[3], 500, {'from': a[1]})
    check.equal(token.allowance(a[1], a[3]), 500)
    token.transferFrom(a[1], a[2], 400, {'from': a[3]})
    check.equal(token.allowance(a[1], a[3]), 100)
    token.transferFrom(a[1], a[2], 100, {'from': a[3]})
    check.equal(token.allowance(a[1], a[3]), 0)

def transfer_from_investor_no_approval():
    '''transferFrom - no approval'''
    check.reverts(
        token.transferFrom,
        (a[1], a[2], 1000, {'from': a[3]}),
        "Insufficient allowance"
    )

def transfer_from_investor_insufficient_approval():
    '''transferFrom - insufficient approval'''
    token.approve(a[3], 500, {'from': a[1]})
    check.reverts(
        token.transferFrom,
        (a[1], a[2], 1000, {'from': a[3]}),
        "Insufficient allowance"
    )

def transfer_from_same_id():
    '''transferFrom - same investor ID'''
    kyc.registerAddresses(kyc.getID(a[1]), [a[-1]], {'from': a[0]})
    token.transferFrom(a[1], a[2], 500, {'from':a[-1]})

def transfer_from_issuer():
    '''issuer transferFrom'''
    token.transferFrom(a[1], a[2], 1000, {'from': a[0]})

def authority_permission():
    '''authority transferFrom permission'''
    tx = issuer.addAuthority([a[-1]], ["0x23b872dd"], 2000000000, 1, {'from':a[0]})
    token.transferFrom(a[1], a[2], 500, {'from': a[-1]})
    issuer.setAuthoritySignatures(issuer.getID(a[-1]), ["0x23b872dd"], False, {'from':a[0]})
    check.reverts(
        token.transferFrom,
        (a[1], a[2], 500, {'from': a[-1]}),
        "Authority not permitted"
    )