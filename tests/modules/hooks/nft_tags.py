#!/usr/bin/python3

from brownie import *
from scripts.deployment import main 

module_source = """
pragma solidity 0.4.25;

interface Modular {
    function setHook(bytes4, bool, bool) external returns (bool);
    function setHookTags(bytes4, bool, bytes1, bytes1[]) external returns (bool);
    function clearHookTags(bytes4, bytes1[]) external returns (bool);
}

contract TestModule {

    Modular owner;
    bool hookReturn;

    constructor(address _owner) public { owner = Modular(_owner); }
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


def setup():
    main(NFToken)
    global issuer, nft, cust, module
    nft = NFToken[0]
    issuer = IssuingEntity[0]
    cust = OwnedCustodian.deploy(a[0], [a[0]], 1)
    issuer.addCustodian(cust, {'from': a[0]})
    nft.mint(a[1], 100, 0, "0x0000", {'from': a[0]}) #    1 - 100
    nft.mint(a[1], 100, 0, "0xaa01", {'from': a[0]}) # 101 - 200
    nft.mint(a[1], 100, 0, "0xaa02", {'from': a[0]}) # 201 - 300
    nft.mint(a[1], 100, 0, "0xff00", {'from': a[0]}) # 301 - 400
    nft.mint(a[1], 100, 0, "0xff01", {'from': a[0]}) # 401 - 500
    nft.mint(a[1], 100, 0, "0xff02", {'from': a[0]}) # 501 - 600
    module = compile_source(module_source)[0].deploy(a[0], nft)
    issuer.attachModule(nft, module, {'from': a[0]})


def checkTransferRange_transferRange():
    '''module.checkTransferRange, nft.transferRange - adjust tags'''
    _transferRange("0x2d79c6d7")


def checkTransferRange_transfer():
    '''module.checkTransferRange, nft.transfer - adjust tags'''
    module.setHookTags("0x2d79c6d7", True, "0xaa", ["0x01"], {'from': a[0]})
    nft.transfer(a[2], 250, {'from': a[1]})
    check.true(nft.getRange(101)[0] == a[1])
    module.setHookTags("0x2d79c6d7", False, "0xaa", ["0x01"], {'from': a[0]})
    nft.transfer(a[2], 120, {'from': a[1]})
    check.true(nft.getRange(101)[0] == a[2])


def checkTransferRange_always():
    '''module.checkTransferRange - toggle always and permitted'''
    _always("0x2d79c6d7")


def transferTokenRange_transferRange():
    '''module.checkTransferRange, nft.transferRange - adjust tags'''
    _transferRange("0xead529f5")


def transferTokenRange_transfer():
    '''module.checkTransferRange, nft.transfer - adjust tags'''
    module.setHookTags("0xead529f5", True, "0xff", ["0x01"], {'from': a[0]})
    nft.transfer(a[2], 250, {'from': a[1]})
    check.reverts(
        nft.transfer,
        (a[2], 250, {'from': a[1]})
    )
    module.setHookTags("0xead529f5", False, "0xff", ["0x01"], {'from': a[0]})
    nft.transfer(a[2], 250, {'from': a[1]})



def transferTokenRange_always():
    '''module.checkTransferRange - toggle always and permitted'''
    _always("0xead529f5")





def _transferRange(sig):
    module.setHookTags(sig, True, "0xff", ["0x01"], {'from': a[0]})
    nft.transferRange(a[2], 301, 310, {'from': a[1]})
    check.reverts(
        nft.transferRange,
        (a[2], 401, 410, {'from': a[1]})
    )
    nft.transferRange(a[2], 501, 510, {'from': a[1]})
    module.setHookTags(sig, True, "0xff", ["0x00"], {'from': a[0]})
    nft.transferRange(a[2], 101, 110, {'from': a[1]})
    check.reverts(
        nft.transferRange,
        (a[2], 311, 331, {'from': a[1]})
    )
    check.reverts(
        nft.transferRange,
        (a[2], 411, 421, {'from': a[1]})
    )
    check.reverts(
        nft.transferRange,
        (a[2], 511, 521, {'from': a[1]})
    )
    module.clearHookTags(sig, ["0xff"], {'from': a[0]})
    nft.transferRange(a[2], 321, 330, {'from': a[1]})
    nft.transferRange(a[2], 421, 430, {'from': a[1]})
    nft.transferRange(a[2], 521, 530, {'from': a[1]})


def _always(sig):
    module.setHook(sig, True, True, {'from': a[0]})
    module.setHookTags(sig, True, "0xff", ["0x01"], {'from': a[0]})
    check.reverts(
        nft.transfer,
        (a[2], 1, {'from': a[1]})
    )
    module.setHook(sig, True, False, {'from': a[0]})
    nft.transfer(a[2], 1, {'from': a[1]})
    check.reverts(
        nft.transferRange,
        (a[2], 401, 410, {'from': a[1]})
    )
    module.setHook(sig, False, False, {'from': a[0]})
    nft.transfer(a[2], 1, {'from': a[1]})
    nft.transferRange(a[2], 401, 410, {'from': a[1]})