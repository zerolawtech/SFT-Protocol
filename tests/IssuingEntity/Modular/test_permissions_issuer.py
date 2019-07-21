#!/usr/bin/python3

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
def setup(approve_many, issuer, nft, token):
    token.mint(issuer, 100000, {'from': accounts[0]})
    nft.mint(issuer, 100000, 0, "0x00", {'from': accounts[0]})


def test_is_permitted(issuer, token):
    '''check permitted'''
    source = module_source.format('0xbb2a8522')
    module = compile_source(source)[0].deploy(token, {'from': accounts[0]})
    assert not token.isPermittedModule(module, "0xbb2a8522")
    issuer.attachModule(token, module, {'from': accounts[0]})
    assert token.isPermittedModule(module, "0xbb2a8522")
    issuer.detachModule(token, module, {'from': accounts[0]})
    assert not token.isPermittedModule(module, "0xbb2a8522")


def test_token_detachModule(issuer, token):
    '''detach module'''
    source = module_source.format('0xbb2a8522')
    module = compile_source(source)[0].deploy(token, {'from': accounts[0]})
    with pytest.reverts():
        module.test(token.detachModule.encode_abi(module), {'from': accounts[0]})
    issuer.attachModule(token, module, {'from': accounts[0]})
    module.test(token.detachModule.encode_abi(module), {'from': accounts[0]})
    with pytest.reverts():
        module.test(token.detachModule.encode_abi(module), {'from': accounts[0]})


def test_token_transferFrom(issuer, token):
    '''token transferFrom'''
    token.transfer(accounts[2], 5000, {'from': accounts[0]})
    _check_permission(
        issuer,
        token,
        '0x23b872dd',
        token.transferFrom.encode_abi(accounts[2], accounts[3], 3000)
    )
    assert token.balanceOf(accounts[2]) == 2000
    assert token.balanceOf(accounts[3]) == 3000


def test_token_modifyAuthorizedSupply(issuer, token):
    '''token modifyAuthorizedSupply'''
    _check_permission(
        issuer,
        token,
        '0xc39f42ed',
        token.modifyAuthorizedSupply.encode_abi("10 ether")
    )
    assert token.authorizedSupply() == "10 ether"


def test_token_mint(issuer, token):
    '''token mint'''
    _check_permission(
        issuer,
        token,
        '0x40c10f19',
        token.mint.encode_abi(accounts[3], 10000)
    )
    assert token.balanceOf(accounts[3]) == 10000


def test_token_burn(issuer, token):
    '''token burn'''
    token.transfer(accounts[2], 5000, {'from': accounts[0]})
    _check_permission(
        issuer,
        token,
        '0x9dc29fac',
        token.burn.encode_abi(accounts[2], 3000)
    )
    assert token.balanceOf(accounts[2]) == 2000


def test_nft_mint(issuer, nft):
    '''nft mint'''
    _check_permission(
        issuer,
        nft,
        "0x15077ec8",
        nft.mint.encode_abi(accounts[2], 10000, 0, "0xff11")
    )
    assert nft.balanceOf(accounts[2]) == 10000


def test_nft_burn(issuer, nft):
    '''nft burn'''
    _check_permission(
        issuer,
        nft,
        "0x9a0d378b",
        nft.burn.encode_abi(1337, 31337)
    )
    assert nft.balanceOf(issuer) == 70000


def test_nft_modifyRange(issuer, nft):
    '''nft modifyRange'''
    _check_permission(
        issuer,
        nft,
        "0x712a516a",
        nft.modifyRange.encode_abi(1, 0, "0xabcd")
    )
    assert nft.getRange(1)[1:5] == (1, 100001, 0, "0xabcd")


def test_nft_modifyRanges(issuer, nft):
    '''nft modifyRanges'''
    _check_permission(
        issuer,
        nft,
        "0x786500aa",
        nft.modifyRanges.encode_abi(100, 200, 0, "0x1111")
    )
    assert nft.getRange(1)[1:5] == (1, 100, 0, "0x0000")
    assert nft.getRange(100)[1:5] == (100, 200, 0, "0x1111")
    assert nft.getRange(200)[1:5] == (200, 100001, 0, "0x0000")


def _check_permission(issuer, contract, sig, calldata):

    # deploy the module
    module = compile_source(module_source.format(sig))[0].deploy(contract, {'from': accounts[0]})

    # check that call fails prior to attaching module
    with pytest.reverts():
        module.test(calldata, {'from': accounts[0]})

    # attach the module and check that the call now succeeds
    issuer.attachModule(contract, module, {'from': accounts[0]})
    module.test(calldata, {'from': accounts[0]})

    # detach the module and check that the call fails again
    issuer.detachModule(contract, module, {'from': accounts[0]})
    with pytest.reverts():
        module.test(calldata, {'from': accounts[0]})
