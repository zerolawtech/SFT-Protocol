#!/usr/bin/python3

import pytest

from brownie import accounts, compile_source

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


@pytest.fixture(scope="module", autouse=True)
def setup(approve_many, issuer, nft):
    nft.mint(issuer, 100000, 0, "0x00", {'from': accounts[0]})


def test_checkTransfer(issuer, nft):
    source = '''checkTransfer(
        address[2] _addr,
        bytes32 _authID,
        bytes32[2] _id,
        uint8[2] _rating,
        uint16[2] _country,
        uint256 _value'''
    _hook(issuer, nft, nft.checkTransfer, (accounts[0], accounts[1], 1000), source, "0x70aaf928")


def test_checkTransferRange(issuer, nft):
    source = '''checkTransferRange(
        address[2] _addr,
        bytes32 _authID,
        bytes32[2] _id,
        uint8[2] _rating,
        uint16[2] _country,
        uint48[2] _range'''
    source = module_source.format("0x2d79c6d7", source)
    module = compile_source(source)[0].deploy(nft, {'from': accounts[0]})
    nft.transferRange(accounts[1], 100, 200, {'from': accounts[0]})
    issuer.attachModule(nft, module, {'from': accounts[0]})
    nft.transferRange(accounts[1], 300, 400, {'from': accounts[0]})
    module.setReturn(False, {'from': accounts[0]})
    with pytest.reverts():
        nft.transferRange(accounts[1], 500, 600, {'from': accounts[0]})
    issuer.detachModule(nft, module, {'from': accounts[0]})
    nft.transferRange(accounts[1], 500, 600, {'from': accounts[0]})


def test_transferTokenRange(issuer, nft):
    source = '''transferTokenRange(
        address[2] _addr,
        bytes32[2] _id,
        uint8[2] _rating,
        uint16[2] _country,
        uint48[2] _range'''
    _hook(issuer, nft, nft.transfer, (accounts[1], 1000), source, "0xead529f5")


def test_transferTokensCustodian(issuer, nft, cust):
    source = '''transferTokensCustodian(
        address _custodian,
        address[2] _addr,
        bytes32[2] _id,
        uint8[2] _rating,
        uint16[2] _country,
        uint256 _value'''
    nft.transfer(accounts[2], 10000, {'from': accounts[0]})
    nft.transfer(cust, 5000, {'from': accounts[2]})
    _hook(
        issuer,
        nft,
        cust.transferInternal,
        (nft, accounts[2], accounts[3], 100),
        source,
        "0x8b5f1240"
    )


def test_totalSupplyChanged(issuer, nft):
    source = '''totalSupplyChanged(
        address _addr,
        bytes32 _id,
        uint8 _rating,
        uint16 _country,
        uint256 _old,
        uint256 _new'''
    _burn(issuer, nft, source, "0x741b5078")
    _hook(issuer, nft, nft.mint, (accounts[2], 1000, 0, "0x00"), source, "0x741b5078")


def _hook(issuer, contract, fn, args, source, sig):
    args = list(args) + [{'from': accounts[0]}]
    source = module_source.format(sig, source)
    module = compile_source(source)[0].deploy(contract, {'from': accounts[0]})
    fn(*args)
    issuer.attachModule(contract, module, {'from': accounts[0]})
    fn(*args)
    module.setReturn(False, {'from': accounts[0]})
    with pytest.reverts():
        fn(*args)
    issuer.detachModule(contract, module, {'from': accounts[0]})
    fn(*args)


def _burn(issuer, nft, source, sig):
    module = compile_source(module_source.format(sig, source))[0].deploy(nft, {'from': accounts[0]})
    nft.burn(100, 200, {'from': accounts[0]})
    issuer.attachModule(nft, module, {'from': accounts[0]})
    nft.burn(300, 400, {'from': accounts[0]})
    module.setReturn(False, {'from': accounts[0]})
    with pytest.reverts():
        nft.burn(500, 600, {'from': accounts[0]})
    issuer.detachModule(nft, module, {'from': accounts[0]})
    nft.burn(500, 600, {'from': accounts[0]})
