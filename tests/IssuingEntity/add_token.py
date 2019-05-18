#!/usr/bin/python3

from brownie import *
from scripts.deployment import deploy_contracts

module_source = '''pragma solidity 0.4.25;
contract TestGovernance {
    address public issuer;
    bool result;
    constructor(address _issuer) public { issuer = _issuer; }
    function setResult(bool _result) external { result = _result; }
    function addToken(address) external returns (bool) { return result; }
}'''


def setup():
    global token, token2, issuer, gov
    token, issuer, _ = deploy_contracts(SecurityToken)

    token2 = accounts[0].deploy(SecurityToken, issuer, "ABC Token", "ABC", 1000000)
    gov = compile_source(module_source)[0].deploy(issuer, {'from': a[0]})

def add_token():
    '''add token'''
    issuer.addToken(token2, {'from': a[0]})

def add_token_twice():
    '''add token - already added'''
    check.reverts(
        issuer.addToken,
        (token, {'from': a[0]}),
        "dev: already set"
    )

def add_token_wrong_issuer():
    '''add token - wrong issuer'''
    issuer2 = accounts[0].deploy(IssuingEntity, [accounts[0]], 1)
    token3 = a[0].deploy(SecurityToken, issuer2, "ABC", "ABC Token", 18)
    check.reverts(
        issuer.addToken,
        (token3, {'from': a[0]}),
        "dev: wrong owner"
    )

def add_token_governance_true():
    '''add token - governance allows'''
    issuer.setGovernance(gov, {'from': a[0]})
    gov.setResult(True, {'from': a[0]})
    issuer.addToken(token2, {'from': a[0]})

def add_token_governance_false():
    '''add token - governance allows'''
    issuer.setGovernance(gov, {'from': a[0]})
    gov.setResult(False, {'from': a[0]})
    check.reverts(
        issuer.addToken,
        (token2, {'from': a[0]}),
        "Action has not been approved"
    )

def add_token_governance_removed():
    '''add token - governance allows'''
    issuer.setGovernance(gov, {'from': a[0]})
    gov.setResult(False, {'from': a[0]})
    check.reverts(
        issuer.addToken,
        (token2, {'from': a[0]}),
        "Action has not been approved"
    )
    issuer.setGovernance("0"*40, {'from': a[0]})
    issuer.addToken(token2, {'from': a[0]})


# def authorized_supply_governance_false():
#     '''modify authorized supply - blocked by governance module'''
#     issuer.setGovernance(gov, {'from': a[0]})
#     gov.setResult(False, {'from': a[0]})
#     check.reverts(
#         token.modifyAuthorizedSupply,
#         (10000, {'from': a[0]}),
#         "Action has not been approved"
#     )

# def authorized_supply_governance_true():
#     '''modify authorized supply - allowed by governance module'''
#     issuer.setGovernance(gov, {'from': a[0]})
#     gov.setResult(True, {'from': a[0]})
#     token.modifyAuthorizedSupply(10000, {'from': a[0]})

# def authorized_supply_governance_removed():
#     '''modify authorized supply - removed governance module'''
#     issuer.setGovernance(gov, {'from': a[0]})
#     gov.setResult(False, {'from': a[0]})
#     check.reverts(
#         token.modifyAuthorizedSupply,
#         (10000, {'from': a[0]}),
#         "Action has not been approved"
#     )
#     issuer.setGovernance("0"*40, {'from': a[0]})
#     token.modifyAuthorizedSupply(10000, {'from': a[0]})
