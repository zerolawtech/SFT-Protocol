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
    global token, issuer, nft, cust
    token = SecurityToken[0]
    issuer = IssuingEntity[0]
    token.mint(issuer, 100000, {'from': a[0]})
    cust = OwnedCustodian.deploy(a[0], [a[0]], 1)
    issuer.addCustodian(cust, {'from': a[0]})
    token.transfer(a[2], 1000, {'from': a[0]})
    token.transfer(cust, 1000, {'from': a[2]})


def is_permitted():
    '''check permitted'''
    module = compile_source(module_source.format('0xbb2a8522'))[0].deploy(a[0], cust)
    check.false(cust.isPermittedModule(module, "0xbb2a8522"))
    check.false(cust.isPermittedModule(module, "0xbeabacc8"))
    cust.attachModule(module, {'from': a[0]})
    check.true(cust.isPermittedModule(module, "0xbb2a8522"))
    check.false(cust.isPermittedModule(module, "0xbeabacc8"))
    cust.detachModule(module, {'from': a[0]})
    check.false(cust.isPermittedModule(module, "0xbb2a8522"))
    check.false(cust.isPermittedModule(module, "0xbeabacc8"))


def token_detachModule():
    '''detach module'''
    module = compile_source(module_source.format('0xbb2a8522'))[0].deploy(a[0], cust)
    check.reverts(
        module.test,
        (cust.detachModule.encode_abi(module), {'from': a[0]})
    )
    cust.attachModule(module, {'from': a[0]})
    module.test(cust.detachModule.encode_abi(module), {'from': a[0]})
    check.reverts(
        module.test,
        (cust.detachModule.encode_abi(module), {'from': a[0]})
    )


def custodian_transfer():
    '''custodian transfer'''
    _check_permission(
        "0xbeabacc8",
        cust.transfer.encode_abi(token, a[2], 400)
    )
    check.equal(token.balanceOf(a[2]), 400)
    check.equal(token.custodianBalanceOf(a[2], cust), 600)


def custodian_transferInternal():
    '''custodian transfer'''

    _check_permission(
        "0x2f98a4c3",
        cust.transferInternal.encode_abi(token, a[2], a[3], 400)
    )
    check.equal(token.custodianBalanceOf(a[2], cust), 600)
    check.equal(token.custodianBalanceOf(a[3], cust), 400)


def _check_permission(sig, calldata):
    
    # deploy the module
    module = compile_source(module_source.format(sig))[0].deploy(a[0], cust)
    
    # check that call fails prior to attaching module
    check.reverts(module.test, (calldata, {'from': a[0]}))
    
    # attach the module and check that the call now succeeds
    cust.attachModule(module, {'from': a[0]})
    module.test(calldata, {'from': a[0]})
    
    # detach the module and check that the call fails again
    cust.detachModule(module, {'from': a[0]})
    check.reverts(module.test, (calldata, {'from': a[0]}))