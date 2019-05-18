#!/usr/bin/python3

from brownie import *
from scripts.deployment import main 

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
    main(SecurityToken)
    global token, issuer, cust
    token = SecurityToken[0]
    issuer = IssuingEntity[0]
    cust = a[0].deploy(OwnedCustodian, [a[0]], 1)
    issuer.addCustodian(cust, {'from': a[0]})
    token.mint(issuer, 100000, {'from': a[0]})


def checkTransfer():
    source = '''checkTransfer(
        address[2] _addr,
        bytes32 _authID,
        bytes32[2] _id,
        uint8[2] _rating,
        uint16[2] _country,
        uint256 _value'''
    _hook(token, token.checkTransfer, (a[0], a[1], 1000), source, "0x70aaf928")


def transferTokens():
    source = '''transferTokens(
        address[2] _addr,
        bytes32[2] _id,
        uint8[2] _rating,
        uint16[2] _country,
        uint256 _value'''
    _hook(token, token.transfer, (a[1], 1000), source, "0x35a341da")


def transferTokensCustodian():
    source = '''transferTokensCustodian(
        address _custodian,
        address[2] _addr,
        bytes32[2] _id,
        uint8[2] _rating,
        uint16[2] _country,
        uint256 _value'''
    token.transfer(a[2], 10000, {'from': a[0]})
    token.transfer(cust, 5000, {'from': a[2]})
    _hook(token, cust.transferInternal, (token, a[2], a[3], 100), source, "0x8b5f1240")


def totalSupplyChanged():
    source = '''totalSupplyChanged(
        address _addr,
        bytes32 _id,
        uint8 _rating,
        uint16 _country,
        uint256 _old,
        uint256 _new'''
    _hook(token, token.burn, (issuer, 1000), source, "0x741b5078")
    _hook(token, token.mint, (a[2], 1000), source, "0x741b5078")


def _hook(contract, fn, args, source, sig):
    args = list(args)+[{'from': a[0]}]
    module = compile_source(module_source.format(sig, source))[0].deploy(contract, {'from': a[0]})
    fn(*args)
    issuer.attachModule(contract, module, {'from': a[0]})
    fn(*args)
    module.setReturn(False, {'from': a[0]})
    check.reverts(fn, args)
    issuer.detachModule(contract, module, {'from': a[0]})
    fn(*args)