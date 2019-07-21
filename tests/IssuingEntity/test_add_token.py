#!/usr/bin/python3

import pytest

from brownie import accounts, compile_source

module_source = '''pragma solidity 0.4.25;
contract TestGovernance {
    address public issuer;
    bool result;
    constructor(address _issuer) public { issuer = _issuer; }
    function setResult(bool _result) external { result = _result; }
    function addToken(address) external returns (bool) { return result; }
}'''


@pytest.fixture(scope="module")
def gov(issuer):
    gov = compile_source(module_source)[0].deploy(issuer, {'from': accounts[0]})
    issuer.setGovernance(gov, {'from': accounts[0]})
    yield gov


@pytest.fixture(scope="module")
def token2(SecurityToken, issuer, accounts, token):
    t = accounts[0].deploy(SecurityToken, issuer, "Test Token2", "TS2", 1000000)
    yield t


def test_add_token(issuer, token2):
    '''add token'''
    issuer.addToken(token2, {'from': accounts[0]})


def test_add_token_twice(issuer, token):
    '''add token - already added'''
    with pytest.reverts("dev: already set"):
        issuer.addToken(token, {'from': accounts[0]})


def test_add_token_wrong_issuer(issuer, IssuingEntity, SecurityToken):
    '''add token - wrong issuer'''
    issuer2 = accounts[0].deploy(IssuingEntity, [accounts[0]], 1)
    token = accounts[0].deploy(SecurityToken, issuer2, "ABC", "ABC Token", 18)
    with pytest.reverts("dev: wrong owner"):
        issuer.addToken(token, {'from': accounts[0]})


def test_add_token_governance_true(issuer, gov, token2):
    '''add token - governance allows'''
    issuer.setGovernance(gov, {'from': accounts[0]})
    gov.setResult(True, {'from': accounts[0]})
    issuer.addToken(token2, {'from': accounts[0]})


def test_add_token_governance_false(issuer, gov, token2):
    '''add token - governance allows'''
    gov.setResult(False, {'from': accounts[0]})
    with pytest.reverts("Action has not been approved"):
        issuer.addToken(token2, {'from': accounts[0]})


def test_add_token_governance_removed(issuer, gov, token2):
    '''add token - governance allows'''
    gov.setResult(False, {'from': accounts[0]})
    with pytest.reverts("Action has not been approved"):
        issuer.addToken(token2, {'from': accounts[0]})
    issuer.setGovernance("0" * 40, {'from': accounts[0]})
    issuer.addToken(token2, {'from': accounts[0]})
