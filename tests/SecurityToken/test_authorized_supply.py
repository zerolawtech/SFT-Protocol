#!/usr/bin/python3

import pytest

from brownie import accounts, compile_source

module_source = '''pragma solidity 0.4.25;
contract TestGovernance {
    address public issuer;
    bool result;
    constructor(address _issuer) public { issuer = _issuer; }
    function setResult(bool _result) external { result = _result; }
    function modifyAuthorizedSupply(address, uint256) external returns (bool) { return result; }
}'''


@pytest.fixture(scope="module")
def gov(issuer):
    g = compile_source(module_source)[0].deploy(issuer, {'from': accounts[0]})
    issuer.setGovernance(g, {'from': accounts[0]})
    yield g


def test_authorized_supply(token):
    '''modify authorized supply'''
    token.modifyAuthorizedSupply(10000, {'from': accounts[0]})
    assert token.authorizedSupply() == 10000
    assert token.totalSupply() == 0
    token.modifyAuthorizedSupply(0, {'from': accounts[0]})
    assert token.authorizedSupply() == 0
    assert token.totalSupply() == 0
    token.modifyAuthorizedSupply(1234567, {'from': accounts[0]})
    assert token.authorizedSupply(), 1234567
    assert token.totalSupply() == 0
    token.modifyAuthorizedSupply(2400000000, {'from': accounts[0]})
    assert token.authorizedSupply(), 2400000000
    assert token.totalSupply() == 0


def test_authorized_supply_governance_false(token, gov):
    '''modify authorized supply - blocked by governance module'''
    gov.setResult(False, {'from': accounts[0]})
    with pytest.reverts("Action has not been approved"):
        token.modifyAuthorizedSupply(10000, {'from': accounts[0]})


def test_authorized_supply_governance_true(token, gov):
    '''modify authorized supply - allowed by governance module'''
    gov.setResult(True, {'from': accounts[0]})
    token.modifyAuthorizedSupply(10000, {'from': accounts[0]})


def test_authorized_supply_governance_removed(issuer, token, gov):
    '''modify authorized supply - removed governance module'''
    gov.setResult(False, {'from': accounts[0]})
    with pytest.reverts("Action has not been approved"):
        token.modifyAuthorizedSupply(10000, {'from': accounts[0]})
    issuer.setGovernance("0" * 40, {'from': accounts[0]})
    token.modifyAuthorizedSupply(10000, {'from': accounts[0]})
