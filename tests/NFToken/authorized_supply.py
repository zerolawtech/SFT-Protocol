#!/usr/bin/python3

from brownie import *
from scripts.deployment import deploy_contracts

module_source = '''pragma solidity 0.4.25;
contract TestGovernance {
    address public issuer;
    bool result;
    constructor(address _issuer) public { issuer = _issuer; }
    function setResult(bool _result) external { result = _result; }
    function modifyAuthorizedSupply(address, uint256) external returns (bool) { return result; }
}'''


def setup():
    global token, issuer, gov
    token, issuer, _ = deploy_contracts(NFToken)
    gov = compile_source(module_source)[0].deploy(issuer, {'from': a[0]})

def authorized_supply():
    '''modify authorized supply'''
    token.modifyAuthorizedSupply(10000, {'from': a[0]})
    check.equal(token.authorizedSupply(), 10000)
    check.equal(token.totalSupply(), 0)
    token.modifyAuthorizedSupply(0, {'from': a[0]})
    check.equal(token.authorizedSupply(), 0)
    check.equal(token.totalSupply(), 0)
    token.modifyAuthorizedSupply(1234567, {'from': a[0]})
    check.equal(token.authorizedSupply(), 1234567)
    check.equal(token.totalSupply(), 0)
    token.modifyAuthorizedSupply(2400000000, {'from': a[0]})
    check.equal(token.authorizedSupply(), 2400000000)
    check.equal(token.totalSupply(), 0)

def authorized_supply_governance_false():
    '''modify authorized supply - blocked by governance module'''
    issuer.setGovernance(gov, {'from': a[0]})
    gov.setResult(False, {'from': a[0]})
    check.reverts(
        token.modifyAuthorizedSupply,
        (10000, {'from': a[0]}),
        "Action has not been approved"
    )

def authorized_supply_governance_true():
    '''modify authorized supply - allowed by governance module'''
    issuer.setGovernance(gov, {'from': a[0]})
    gov.setResult(True, {'from': a[0]})
    token.modifyAuthorizedSupply(10000, {'from': a[0]})

def authorized_supply_governance_removed():
    '''modify authorized supply - removed governance module'''
    issuer.setGovernance(gov, {'from': a[0]})
    gov.setResult(False, {'from': a[0]})
    check.reverts(
        token.modifyAuthorizedSupply,
        (10000, {'from': a[0]}),
        "Action has not been approved"
    )
    issuer.setGovernance("0"*40, {'from': a[0]})
    token.modifyAuthorizedSupply(10000, {'from': a[0]})
