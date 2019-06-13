#!/usr/bin/python3

from brownie import *
from scripts.deployment import main, deploy_custodian 

module_source = """
pragma solidity 0.4.25;

contract TestModule {{

    address owner;
    bool hookReturn = true;

    constructor(address _owner) public {{ owner = _owner; }}
    function getOwner() external view returns (address) {{ return owner; }}
    
    function getPermissions()
        external
        pure
        returns
    (
        bytes4[] permissions,
        bytes4[] hooks,
        uint256 hookBools
    )
    {{
        bytes4[] memory _hooks = new bytes4[](1);
        _hooks[0] = {};
        return (permissions, _hooks, uint256(0)-1);
    }}

    function setReturn(bool _return) external {{
        hookReturn = _return;
    }}

    function {}) external returns (bool) {{
        if (!hookReturn) {{
            revert();
        }}
        return true;
    }}

}}"""


def setup():
    global token, issuer, cust
    token, issuer, _ = main(SecurityToken, (1,), (1,2))
    cust = deploy_custodian()
    token.mint(issuer, 100000, {'from': a[0]})
    token.transfer(a[2], 10000, {'from': a[0]})


def custodian_sentTokens():
    source = '''sentTokens(
        address _token,
        address _to,
        uint256 _value'''
    token.transfer(cust, 10000, {'from': a[0]})
    _hook(cust.transfer, (token, a[0], 100), source, "0xb4684410")


def custodian_receivedTokens():
    source = '''receivedTokens(
        address _token,
        address _from,
        uint256 _value'''
    _hook(token.transfer, (cust, 1000), source, "0xb15bcbc4")


def custodian_internalTransfer():
    source = '''internalTransfer(
        address _token,
        address _from,
        address _to,
        uint256 _value'''
    token.transfer(cust, 10000, {'from': a[0]})
    _hook(cust.transferInternal, (token, a[0], a[2], 100), source, "0x44a29e2a")


def _hook(fn, args, source, sig):
    args = list(args)+[{'from': a[0]}]
    module = compile_source(module_source.format(sig, source))[0].deploy(cust, {'from': a[0]})
    fn(*args)
    cust.attachModule(module, {'from': a[0]})
    fn(*args)
    module.setReturn(False, {'from': a[0]})
    check.reverts(fn, args)
    cust.detachModule(module, {'from': a[0]})
    fn(*args)