#!/usr/bin/python3

from brownie import *
from scripts.deployment import main


def setup():
    main(SecurityToken)
    global token, issuer, cust
    token = SecurityToken[0]
    issuer = IssuingEntity[0]
    cust = a[0].deploy(OwnedCustodian, [a[0]], 1)
    issuer.addCustodian(cust, {'from': a[0]})

def mint_zero():
    '''mint 0 tokens'''
    check.reverts(
        token.mint,
        (issuer, 0, {'from': a[0]}),
        "dev: mint 0"
    )
    token.mint(issuer, 10000, {'from': a[0]})
    check.reverts(
        token.mint,
        (issuer, 0, {'from': a[0]}),
        "dev: mint 0"
    )

def burn_zero():
    '''burn 0 tokens'''
    check.reverts(
        token.burn,
        (issuer, 0, {'from': a[0]}),
        "dev: burn 0"
    )
    token.mint(issuer, 10000, {'from': a[0]})
    check.reverts(
        token.burn,
        (issuer, 0, {'from': a[0]}),
        "dev: burn 0"
    )

def authorized_below_total():
    '''authorized supply below total supply'''
    token.mint(issuer, 100000, {'from': a[0]})
    check.reverts(
        token.modifyAuthorizedSupply,
        (10000, {'from': a[0]}),
        "dev: auth below total"
    )

def total_above_authorized():
    '''total supply above authorized'''
    token.modifyAuthorizedSupply(10000, {'from': a[0]})
    check.reverts(
        token.mint,
        (issuer, 20000, {'from': a[0]}),
        "dev: exceed auth"
    )
    token.mint(issuer, 6000, {'from': a[0]})
    check.reverts(
        token.mint,
        (issuer, 6000, {'from': a[0]}),
        "dev: exceed auth"
    )
    token.mint(issuer, 4000, {'from': a[0]})
    check.reverts(
        token.mint,
        (issuer, 1, {'from': a[0]}),
        "dev: exceed auth"
    )
    check.reverts(
        token.mint,
        (issuer, 0, {'from': a[0]}),
        "dev: mint 0"
    )

def burn_exceeds_balance():
    '''burn exceeds balance'''
    check.reverts(token.burn, (issuer, 100, {'from': a[0]}))
    token.mint(issuer, 4000, {'from': a[0]})
    check.reverts(token.burn, (issuer, 5000, {'from': a[0]}))
    token.burn(issuer, 3000, {'from': a[0]})
    check.reverts(token.burn, (issuer, 1001, {'from': a[0]}))
    token.burn(issuer, 1000, {'from': a[0]})
    check.reverts(token.burn, (issuer, 100, {'from': a[0]}))


def mint_to_custodian():
    '''mint to custodian'''
    check.reverts(
        token.mint,
        (cust, 6000, {'from': a[0]}),
        "dev: custodian"
    )


def burn_from_custodian():
    '''burn from custodian'''
    token.mint(issuer, 10000, {'from': a[0]})
    token.transfer(cust, 10000, {'from': a[0]})
    check.reverts(
        token.burn,
        (cust, 5000, {'from': a[0]}),
        "dev: custodian"
    )