#!/usr/bin/python3

import pytest

from brownie import accounts, compile_source

module_source = """
pragma solidity 0.4.25;

interface IModular {
    function setHook(bytes4, bool, bool) external returns (bool);
    function setHookTags(bytes4, bool, bytes1, bytes1[]) external returns (bool);
    function clearHookTags(bytes4, bytes1[]) external returns (bool);
}

contract TestModule {

    IModular owner;
    bool hookReturn;

    constructor(address _owner) public { owner = IModular(_owner); }
    function getOwner() external view returns (address) { return owner; }
    function setActive(bool _return) external { hookReturn = _return; }

    function getPermissions() external pure returns(
        bytes4[] permissions, bytes4[] hooks, uint256 hookBools
    ) {
        bytes4[] memory _hooks = new bytes4[](2);
        _hooks[0] = 0x2d79c6d7; // checkTransferRange
        _hooks[1] = 0xead529f5; // transferTokenRange
        return (permissions, _hooks, 3);
    }

    function setHook(
        bytes4 _sig, bool _active, bool _always
    ) external returns (bool) {
        require(owner.setHook(_sig, _active, _always));
        return true;
    }

    function setHookTags(
        bytes4 _sig, bool _value, bytes1 _tagBase, bytes1[] _tags
    ) external returns (bool) {
        require(owner.setHookTags(_sig, _value, _tagBase, _tags));
        return true;
    }

    function clearHookTags(bytes4 _sig, bytes1[] _tagBase) external returns (bool) {
        require(owner.clearHookTags(_sig, _tagBase));
        return true;
    }

    function checkTransferRange(
        address[2], bytes32, bytes32[2], uint8[2], uint16[2], uint48[2]
    ) external view returns (bool) {
        revert();
    }

    function transferTokenRange(
        address[2], bytes32[2], uint8[2], uint16[2], uint48[2]
    ) external returns (bool) {
        revert();
    }
}"""


@pytest.fixture(scope="module", autouse=True)
def setup(id1, id2, issuer, nft):
    nft.mint(accounts[1], 100, 0, "0x0000", {'from': accounts[0]})  # 1   - 100
    nft.mint(accounts[1], 100, 0, "0xaa01", {'from': accounts[0]})  # 101 - 200
    nft.mint(accounts[1], 100, 0, "0xaa02", {'from': accounts[0]})  # 201 - 300
    nft.mint(accounts[1], 100, 0, "0xff00", {'from': accounts[0]})  # 301 - 400
    nft.mint(accounts[1], 100, 0, "0xff01", {'from': accounts[0]})  # 401 - 500
    nft.mint(accounts[1], 100, 0, "0xff02", {'from': accounts[0]})  # 501 - 600


@pytest.fixture(scope="module")
def module(nft, issuer):
    m = compile_source(module_source)[0].deploy(nft, {'from': accounts[0]})
    issuer.attachModule(nft, m, {'from': accounts[0]})
    yield m


def test_checkTransferRange_transferRange(nft, module):
    '''module.checkTransferRange, nft.transferRange - adjust tags'''
    _transferRange(nft, module, "0x2d79c6d7")


def test_checkTransferRange_transfer(nft, module):
    '''module.checkTransferRange, nft.transfer - adjust tags'''
    module.setHookTags("0x2d79c6d7", True, "0xaa", ["0x01"], {'from': accounts[0]})
    nft.transfer(accounts[2], 250, {'from': accounts[1]})
    assert nft.getRange(101)[0] == accounts[1]
    module.setHookTags("0x2d79c6d7", False, "0xaa", ["0x01"], {'from': accounts[0]})
    nft.transfer(accounts[2], 120, {'from': accounts[1]})
    assert nft.getRange(101)[0] == accounts[2]


def test_checkTransferRange_always(nft, module):
    '''module.checkTransferRange - toggle always and permitted'''
    _always(nft, module, "0x2d79c6d7")


def test_transferTokenRange_transferRange(nft, module):
    '''module.checkTransferRange, nft.transferRange - adjust tags'''
    _transferRange(nft, module, "0xead529f5")


def test_transferTokenRange_transfer(nft, module):
    '''module.checkTransferRange, nft.transfer - adjust tags'''
    module.setHookTags("0xead529f5", True, "0xff", ["0x01"], {'from': accounts[0]})
    nft.transfer(accounts[2], 250, {'from': accounts[1]})
    with pytest.reverts():
        nft.transfer(accounts[2], 250, {'from': accounts[1]})
    module.setHookTags("0xead529f5", False, "0xff", ["0x01"], {'from': accounts[0]})
    nft.transfer(accounts[2], 250, {'from': accounts[1]})


def test_transferTokenRange_always(nft, module):
    '''module.checkTransferRange - toggle always and permitted'''
    _always(nft, module, "0xead529f5")


def _transferRange(nft, module, sig):
    module.setHookTags(sig, True, "0xff", ["0x01"], {'from': accounts[0]})
    nft.transferRange(accounts[2], 301, 310, {'from': accounts[1]})
    with pytest.reverts():
        nft.transferRange(accounts[2], 401, 410, {'from': accounts[1]})
    nft.transferRange(accounts[2], 501, 510, {'from': accounts[1]})
    module.setHookTags(sig, True, "0xff", ["0x00"], {'from': accounts[0]})
    nft.transferRange(accounts[2], 101, 110, {'from': accounts[1]})
    with pytest.reverts():
        nft.transferRange(accounts[2], 311, 331, {'from': accounts[1]})
    with pytest.reverts():
        nft.transferRange(accounts[2], 411, 421, {'from': accounts[1]})
    with pytest.reverts():
        nft.transferRange(accounts[2], 511, 521, {'from': accounts[1]})
    module.clearHookTags(sig, ["0xff"], {'from': accounts[0]})
    nft.transferRange(accounts[2], 321, 330, {'from': accounts[1]})
    nft.transferRange(accounts[2], 421, 430, {'from': accounts[1]})
    nft.transferRange(accounts[2], 521, 530, {'from': accounts[1]})


def _always(nft, module, sig):
    module.setHook(sig, True, True, {'from': accounts[0]})
    module.setHookTags(sig, True, "0xff", ["0x01"], {'from': accounts[0]})
    with pytest.reverts():
        nft.transfer(accounts[2], 1, {'from': accounts[1]})
    module.setHook(sig, True, False, {'from': accounts[0]})
    nft.transfer(accounts[2], 1, {'from': accounts[1]})
    with pytest.reverts():
        nft.transferRange(accounts[2], 401, 410, {'from': accounts[1]})
    module.setHook(sig, False, False, {'from': accounts[0]})
    nft.transfer(accounts[2], 1, {'from': accounts[1]})
    nft.transferRange(accounts[2], 401, 410, {'from': accounts[1]})
