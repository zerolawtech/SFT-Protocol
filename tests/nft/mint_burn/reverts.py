#!/usr/bin/python3

from brownie import *
from scripts.deployment import main


def setup():
    main(NFToken)
    global token, issuer, cust
    token = NFToken[0]
    issuer = IssuingEntity[0]
    cust = a[0].deploy(OwnedCustodian, [a[0]], 1)
    issuer.addCustodian(cust, {'from': a[0]})

def mint_zero():
    '''mint 0 tokens'''
    check.reverts(
        token.mint,
        (issuer, 0, 0, "0x00", {'from': a[0]}),
        "dev: mint 0"
    )
    token.mint(issuer, 10000, 0, "0x00", {'from': a[0]})
    check.reverts(
        token.mint,
        (issuer, 0, 0, "0x00", {'from': a[0]}),
        "dev: mint 0"
    )

def mint_time():
    '''mint - lock time < now'''
    check.reverts(
        token.mint,
        (issuer, 1000, 1, "0x00", {'from': a[0]}),
        "dev: time"
    )

def mint_overflow():
    '''mint - overflows'''
    token.modifyAuthorizedSupply(2**49, {'from': a[0]})
    token.mint(issuer, (2**48)-10, 0, "0x00", {'from': a[0]})
    check.reverts(
        token.mint,
        (issuer, 1000, 1, "0x00", {'from': a[0]}),
        "dev: overflow"
    )
    check.reverts(
        token.mint,
        (issuer, 9, 1, "0x00", {'from': a[0]}),
        "dev: upper bound"
    )


def burn_zero():
    '''burn 0 tokens'''
    check.reverts(
        token.burn,
        (1, 1, {'from': a[0]}),
        "dev: burn 0"
    )
    token.mint(issuer, 10000, 0, "0x00", {'from': a[0]})
    check.reverts(
        token.burn,
        (1, 1, {'from': a[0]}),
        "dev: burn 0"
    )

def burn_exceeds_balance():
    '''burn exceeds balance'''
    check.reverts(
        token.burn,
        (1, 101, {'from': a[0]}),
        "dev: exceeds upper bound"
    )
    token.mint(issuer, 4000, 0, "0x00", {'from': a[0]})
    check.reverts(
        token.burn,
        (1, 5001, {'from': a[0]}),
        "dev: exceeds upper bound"
    )
    token.burn(1, 3001, {'from': a[0]})
    check.reverts(
        token.burn,
        (3001, 4002, {'from': a[0]}),
        "dev: exceeds upper bound"
    )
    token.burn(3001, 4001, {'from': a[0]})
    check.reverts(
        token.burn,
        (4001, 4101, {'from': a[0]}),
        "dev: exceeds upper bound"
    )


def burn_multiple_ranges():
    '''burn multiple ranges'''
    token.mint(issuer, 1000, 0, "0x00", {'from': a[0]})
    token.mint(issuer, 1000, 0, "0x01", {'from': a[0]})
    check.reverts(
        token.burn,
        (500, 1500, {'from': a[0]}),
        "dev: multiple ranges"
    )


def reburn():
    '''burn already burnt tokens'''
    token.mint(issuer, 1000, "0x00", 0, {'from': a[0]})
    token.burn(100, 200, {'from': a[0]})
    check.reverts(
        token.burn,
        (100, 200, {'from': a[0]}),
        "dev: already burnt"
    )

def authorized_below_total():
    '''authorized supply below total supply'''
    token.mint(issuer, 100000, "0x00", 0, {'from': a[0]})
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
        (issuer, 20000, 0, "0x00", {'from': a[0]}),
        "dev: exceed auth"
    )
    token.mint(issuer, 6000, 0, "0x00", {'from': a[0]})
    check.reverts(
        token.mint,
        (issuer, 6000, 0, "0x00", {'from': a[0]}),
        "dev: exceed auth"
    )
    token.mint(issuer, 4000, 0, "0x00", {'from': a[0]})
    check.reverts(
        token.mint,
        (issuer, 1, 0, "0x00", {'from': a[0]}),
        "dev: exceed auth"
    )
    check.reverts(
        token.mint,
        (issuer, 0, 0, "0x00", {'from': a[0]}),
        "dev: mint 0"
    )


def mint_to_custodian():
    '''mint to custodian'''
    check.reverts(
        token.mint,
        (cust, 6000, 0, "0x00", {'from': a[0]}),
        "dev: custodian"
    )


def burn_from_custodian():
    '''burn from custodian'''
    token.mint(issuer, 10000, 0, "0x00", {'from': a[0]})
    token.transfer(cust, 10000, {'from': a[0]})
    check.reverts(
        token.burn,
        (1, 5000, {'from': a[0]}),
        "dev: custodian"
    )