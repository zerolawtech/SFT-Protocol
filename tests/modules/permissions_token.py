#!/usr/bin/python3

from brownie import *
from scripts.deployment import main

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


def setup():
    main(SecurityToken)
    global token, issuer, nft
    token = SecurityToken[0]
    issuer = IssuingEntity[0]
    token.mint(issuer, 100000, {'from': a[0]})
    nft = NFToken.deploy(a[0], issuer, "NFToken", "TST", 1000000)
    issuer.addToken(nft, {'from': a[0]})
    nft.mint(issuer, 100000, 0, "0x00", {'from': a[0]})


def is_permitted():
    '''check permitted'''
    module = compile_source(module_source.format('0xbb2a8522'))[0].deploy(a[0], token)
    check.false(token.isPermittedModule(module, "0xbb2a8522"))
    issuer.attachModule(token, module, {'from': a[0]})
    check.true(token.isPermittedModule(module, "0xbb2a8522"))
    issuer.detachModule(token, module, {'from': a[0]})
    check.false(token.isPermittedModule(module, "0xbb2a8522"))


def token_detachModule():
    '''detach module'''
    module = compile_source(module_source.format('0xbb2a8522'))[0].deploy(a[0], token)
    check.reverts(
        module.test,
        (token.detachModule.encode_abi(module), {'from': a[0]})
    )
    issuer.attachModule(token, module, {'from': a[0]})
    module.test(token.detachModule.encode_abi(module), {'from': a[0]})
    check.reverts(
        module.test,
        (token.detachModule.encode_abi(module), {'from': a[0]})
    )


def token_transferFrom():
    '''token transferFrom'''
    token.transfer(a[2], 5000, {'from': a[0]})
    _check_permission(
        token,
        '0x23b872dd',
        token.transferFrom.encode_abi(a[2], a[3], 3000)
    )
    check.equal(token.balanceOf(a[2]), 2000)
    check.equal(token.balanceOf(a[3]), 3000)


def token_modifyAuthorizedSupply():
    '''token modifyAuthorizedSupply'''
    _check_permission(
        token,
        '0xc39f42ed',
        token.modifyAuthorizedSupply.encode_abi("10 ether")
    )
    check.equal(token.authorizedSupply(), "10 ether")


def token_mint():
    '''token mint'''
    _check_permission(
        token,
        '0x40c10f19',
        token.mint.encode_abi(a[3], 10000)
    )
    check.equal(token.balanceOf(a[3]), 10000)


def token_burn():
    '''token burn'''
    token.transfer(a[2], 5000, {'from': a[0]})
    _check_permission(
        token,
        '0x9dc29fac',
        token.burn.encode_abi(a[2], 3000)
    )
    check.equal(token.balanceOf(a[2]), 2000)


def nft_mint():
    '''nft mint'''
    _check_permission(
        nft,
        "0x15077ec8",
        nft.mint.encode_abi(a[2], 10000, 0, "0xff11")
    )
    check.equal(nft.balanceOf(a[2]), 10000)
    

def nft_burn():
    '''nft burn'''
    _check_permission(
        nft,
        "0x9a0d378b",
        nft.burn.encode_abi(1337, 31337)
    )
    check.equal(nft.balanceOf(issuer), 70000)


def nft_modifyRange():
    '''nft modifyRange'''
    _check_permission(
        nft,
        "0x712a516a",
        nft.modifyRange.encode_abi(1, 0, "0xabcd")
    )
    check.equal(nft.getRange(1)[1:5], (1, 100001, 0, "0xabcd"))


def nft_modifyRanges():
    '''nft modifyRanges'''
    _check_permission(
        nft,
        "0x786500aa",
        nft.modifyRanges.encode_abi(100, 200, 0, "0x1111")
    )
    check.equal(nft.getRange(1)[1:5], (1, 100, 0, "0x0000"))
    check.equal(nft.getRange(100)[1:5], (100, 200, 0, "0x1111"))
    check.equal(nft.getRange(200)[1:5], (200, 100001, 0, "0x0000"))


def _check_permission(contract, sig, calldata):
    
    # deploy the module
    module = compile_source(module_source.format(sig))[0].deploy(a[0], contract)
    
    # check that call fails prior to attaching module
    check.reverts(module.test, (calldata, {'from': a[0]}))
    
    # attach the module and check that the call now succeeds
    issuer.attachModule(contract, module, {'from': a[0]})
    module.test(calldata, {'from': a[0]})
    
    # detach the module and check that the call fails again
    issuer.detachModule(contract, module, {'from': a[0]})
    check.reverts(module.test, (calldata, {'from': a[0]}))