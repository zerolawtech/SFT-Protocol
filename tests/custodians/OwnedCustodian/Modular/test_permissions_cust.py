#!/usr/bin/python3

import functools
import pytest

from brownie import accounts, compile_source

module_source = """
pragma solidity 0.4.25;

contract TestModule {{

    address owner;

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
        bytes4[] memory _permissions = new bytes4[](1);
        _permissions[0] = {};
        return (_permissions, hooks, 0);
    }}

    function test(bytes _data) external {{
        require(owner.call(_data));
    }}

}}"""


@pytest.fixture(scope="module", autouse=True)
def permissions_setup(token, cust):
    token.transfer(cust, 10000, {'from': accounts[2]})


@pytest.fixture(scope="module")
def check_permission(cust):
    yield functools.partial(_check_permission, cust)


def test_is_permitted(cust):
    '''check permitted'''
    source = module_source.format('0xbb2a8522')
    module = compile_source(source)[0].deploy(cust, {'from': accounts[0]})
    assert not cust.isPermittedModule(module, "0xbb2a8522")
    assert not cust.isPermittedModule(module, "0xbeabacc8")
    cust.attachModule(module, {'from': accounts[0]})
    assert cust.isPermittedModule(module, "0xbb2a8522")
    assert not cust.isPermittedModule(module, "0xbeabacc8")
    cust.detachModule(module, {'from': accounts[0]})
    assert not cust.isPermittedModule(module, "0xbb2a8522")
    assert not cust.isPermittedModule(module, "0xbeabacc8")


def test_token_detachModule(cust):
    '''detach module'''
    source = module_source.format('0xbb2a8522')
    module = compile_source(source)[0].deploy(cust, {'from': accounts[0]})
    with pytest.reverts():
        module.test(cust.detachModule.encode_abi(module), {'from': accounts[0]})
    cust.attachModule(module, {'from': accounts[0]})
    module.test(cust.detachModule.encode_abi(module), {'from': accounts[0]})
    with pytest.reverts():
        module.test(cust.detachModule.encode_abi(module), {'from': accounts[0]})


def test_custodian_transfer(check_permission, token, cust):
    '''custodian transfer'''
    check_permission(
        "0xbeabacc8",
        cust.transfer.encode_abi(token, accounts[2], 4000)
    )
    assert token.balanceOf(accounts[2]) == 4000
    assert token.custodianBalanceOf(accounts[2], cust) == 6000


def test_custodian_transferInternal(check_permission, token, cust):
    check_permission(
        "0x2f98a4c3",
        cust.transferInternal.encode_abi(token, accounts[2], accounts[3], 4000)
    )
    assert token.custodianBalanceOf(accounts[2], cust) == 6000
    assert token.custodianBalanceOf(accounts[3], cust) == 4000


def _check_permission(cust, sig, calldata):

    # deploy the module
    module = compile_source(module_source.format(sig))[0].deploy(cust, {'from': accounts[0]})

    # check that call fails prior to attaching module
    with pytest.reverts():
        module.test(calldata, {'from': accounts[0]})

    # attach the module and check that the call now succeeds
    cust.attachModule(module, {'from': accounts[0]})
    module.test(calldata, {'from': accounts[0]})

    # detach the module and check that the call fails again
    cust.detachModule(module, {'from': accounts[0]})
    with pytest.reverts():
        module.test(calldata, {'from': accounts[0]})
