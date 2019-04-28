#!/usr/bin/python3

from brownie import *
from scripts.deployment import main


def setup():
    config['test']['always_transact'] = False
    main(SecurityToken)
    global token, issuer
    token = SecurityToken[0]
    issuer = IssuingEntity[0]

def add_authority():
    '''add an authority'''
    issuer.addAuthority([a[-1]], [], 2000000000, 1, {'from': a[0]})
    check.equal(issuer.getAuthority(issuer.getID(a[-1])), (1, 1, 2000000000))

def zero_threshold():
    '''threshold zero'''
    check.reverts(
        issuer.addAuthority,
        ([a[-1]], [], 2000000000, 0, {'from': a[0]}),
        "dev: threshold zero"
    )

def high_threshold():
    '''threshold too low'''
    check.reverts(
        issuer.addAuthority,
        ([a[-1],a[-2]], [], 2000000000, 3, {'from': a[0]}),
        "dev: treshold > count"
    )
    check.reverts(
        issuer.addAuthority,
        ([], [], 2000000000, 1, {'from': a[0]}),
        "dev: treshold > count"
    )

def repeat_addr():
    '''repeat address in addAuthority array'''
    check.reverts(
        issuer.addAuthority,
        ([a[-1],a[-1]], [], 2000000000, 1, {'from': a[0]}),
        "dev: known address"
    )

def known_address():
    '''known address'''
    check.reverts(
        issuer.addAuthority,
        ([a[0]], [], 2000000000, 1, {'from': a[0]}),
        "dev: known address"
    )
    token.mint(a[1], 100, {'from':a[0]})
    check.reverts(
        issuer.addAuthority,
        ([a[1]], [], 2000000000, 1, {'from': a[0]}),
        "dev: known address"
    )

def known_auth():
    '''known authority'''
    issuer.addAuthority([a[-1]], [], 2000000000, 1, {'from': a[0]})
    check.reverts(
        issuer.addAuthority,
        ([a[-1]], [], 2000000000, 1, {'from': a[0]}),
        "dev: known authority"
    )
