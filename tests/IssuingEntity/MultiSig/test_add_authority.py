#!/usr/bin/python3

import pytest

from brownie import accounts


def test_add_authority(issuer):
    '''add an authority'''
    issuer.addAuthority([accounts[-1]], [], 2000000000, 1, {'from': accounts[0]})
    assert issuer.getAuthority(issuer.getID(accounts[-1])) == (1, 1, 2000000000)


def test_zero_threshold(issuer):
    '''threshold zero'''
    with pytest.reverts("dev: threshold zero"):
        issuer.addAuthority([accounts[-1]], [], 2000000000, 0, {'from': accounts[0]})


def test_high_threshold(issuer):
    '''threshold too low'''
    with pytest.reverts("dev: treshold > count"):
        issuer.addAuthority([accounts[-1], accounts[-2]], [], 2000000000, 3, {'from': accounts[0]})
    with pytest.reverts("dev: treshold > count"):
        issuer.addAuthority([], [], 2000000000, 1, {'from': accounts[0]})


def test_repeat_addr(issuer):
    '''repeat address in addAuthority array'''
    with pytest.reverts("dev: known address"):
        issuer.addAuthority([accounts[-1], accounts[-1]], [], 2000000000, 1, {'from': accounts[0]})


def test_known_address(issuer, token, id1):
    '''known address'''
    with pytest.reverts("dev: known address"):
        issuer.addAuthority([accounts[0]], [], 2000000000, 1, {'from': accounts[0]})
    token.mint(accounts[1], 100, {'from': accounts[0]})
    with pytest.reverts("dev: known address"):
        issuer.addAuthority([accounts[1]], [], 2000000000, 1, {'from': accounts[0]})


def test_known_auth(issuer):
    '''known authority'''
    issuer.addAuthority([accounts[-1]], [], 2000000000, 1, {'from': accounts[0]})
    with pytest.reverts("dev: known authority"):
        issuer.addAuthority([accounts[-1]], [], 2000000000, 1, {'from': accounts[0]})
