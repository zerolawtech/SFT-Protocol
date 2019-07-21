#!/usr/bin/python3

import pytest

from brownie import accounts, compile_source

module_source = """
pragma solidity 0.4.25;

contract TestModule {

    address owner;

    constructor(address _owner) public { owner = _owner; }
    function getOwner() external view returns (address) { return owner; }

    function getPermissions()
        external
        pure
        returns
    (
        bytes4[] permissions,
        bytes4[] hooks,
        uint256 hookBools
    )
    {
        return (permissions, hooks, 0);
    }

}"""


@pytest.fixture(scope="module")
def TestModule():
    yield compile_source(module_source)[0]


@pytest.fixture(scope="module")
def module_token(TestModule, token):
    module = accounts[0].deploy(TestModule, token)
    yield module


@pytest.fixture(scope="module")
def module_issuer(TestModule, issuer):
    module = accounts[0].deploy(TestModule, issuer)
    yield module


def test_attach_token(issuer, token, module_token):
    '''attach a token module'''
    assert token.isActiveModule(module_token) is False
    issuer.attachModule(token, module_token, {'from': accounts[0]})
    assert token.isActiveModule(module_token) is True


def test_detach_token(issuer, token, module_token):
    '''detach a token module'''
    issuer.attachModule(token, module_token, {'from': accounts[0]})
    issuer.detachModule(token, module_token, {'from': accounts[0]})
    assert token.isActiveModule(module_token) is False


def test_attach_via_token(token, module_token):
    '''cannot attach directly via token'''
    with pytest.reverts("dev: only issuer"):
        token.attachModule(module_token, {'from': accounts[0]})


def test_detach_via_token(issuer, token, module_token):
    '''cannot detach directly via token'''
    issuer.attachModule(token, module_token, {'from': accounts[0]})
    with pytest.reverts("dev: only issuer"):
        token.detachModule(module_token, {'from': accounts[0]})


def test_attach_issuer(issuer, token, module_issuer):
    '''attach an issuer module'''
    assert token.isActiveModule(module_issuer) is False
    issuer.attachModule(token, module_issuer, {'from': accounts[0]})
    assert token.isActiveModule(module_issuer) is True


def test_detach_issuer(issuer, token, module_issuer):
    '''detach an issuer module'''
    issuer.attachModule(token, module_issuer, {'from': accounts[0]})
    issuer.detachModule(token, module_issuer, {'from': accounts[0]})
    assert token.isActiveModule(module_issuer) is False


def test_already_active(issuer, token, module_issuer, module_token):
    '''attach already active module'''
    issuer.attachModule(token, module_issuer, {'from': accounts[0]})
    with pytest.reverts("dev: already active"):
        issuer.attachModule(token, module_issuer, {'from': accounts[0]})
    issuer.attachModule(token, module_token, {'from': accounts[0]})
    with pytest.reverts("dev: already active"):
        issuer.attachModule(token, module_token, {'from': accounts[0]})


def test_token_locked(issuer, token, module_token):
    '''attach and detach - locked token'''
    issuer.setTokenRestriction(token, True, {'from': accounts[0]})
    issuer.attachModule(token, module_token, {'from': accounts[0]})
    issuer.detachModule(token, module_token, {'from': accounts[0]})


def test_attach_unknown_target(issuer, module_token):
    '''attach and detach - unknown target'''
    with pytest.reverts("dev: unknown target"):
        issuer.attachModule(accounts[0], module_token, {'from': accounts[0]})
    with pytest.reverts("dev: unknown target"):
        issuer.detachModule(accounts[0], module_token, {'from': accounts[0]})
