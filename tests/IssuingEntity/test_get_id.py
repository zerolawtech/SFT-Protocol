#!/usr/bin/python3

import pytest

from brownie import accounts


@pytest.fixture(scope="module", autouse=True)
def setup(issuer, token, kyc2):
    issuer.setRegistrar(kyc2, False, {'from': accounts[0]})
    token.mint(issuer, 1000000, {'from': accounts[0]})


@pytest.fixture(scope="module")
def kyc2(KYCRegistrar, issuer):
    kyc2 = accounts[0].deploy(KYCRegistrar, [accounts[0]], 1)
    issuer.setRegistrar(kyc2, False, {'from': accounts[0]})
    yield kyc2


def test_unknown_address(issuer):
    '''unknown address'''
    issuer.getID(accounts[0])
    with pytest.reverts("Address not registered"):
        issuer.getID(accounts[1])


def test_registrar_restricted(issuer, kyc):
    '''registrar restricted'''
    kyc.addInvestor("0x1234", 1, 1, 1, 9999999999, (accounts[1],), {'from': accounts[0]})
    issuer.getID.transact(accounts[1])
    issuer.setRegistrar(kyc, True, {'from': accounts[0]})
    with pytest.reverts("Registrar restricted"):
        issuer.getID(accounts[1])


def test_different_registrar(issuer, kyc, kyc2):
    '''multiple registrars, different addresses'''
    kyc.addInvestor("0x1234", 1, 1, 1, 9999999999, (accounts[1], accounts[3]), {'from': accounts[0]})
    kyc2.addInvestor("0x1234", 1, 1, 1, 9999999999, (accounts[1], accounts[2]), {'from': accounts[0]})
    issuer.setRegistrar(kyc2, True, {'from': accounts[0]})
    issuer.getID.transact(accounts[1])
    issuer.setRegistrar(kyc2, False, {'from': accounts[0]})
    with pytest.reverts("Address not registered"):
        issuer.getID(accounts[2])
    issuer.getID(accounts[3])


def test_restrict_registrar(issuer, kyc, kyc2):
    '''change registrar'''
    kyc.addInvestor("0x1234", 1, 1, 1, 9999999999, (accounts[1], accounts[3]), {'from': accounts[0]})
    kyc2.addInvestor("0x1234", 1, 1, 1, 9999999999, (accounts[1], accounts[2]), {'from': accounts[0]})
    issuer.getID(accounts[1])
    issuer.setRegistrar(kyc, True, {'from': accounts[0]})
    issuer.getID(accounts[1])
    issuer.getID(accounts[2])
    with pytest.reverts("Address not registered"):
        issuer.getID(accounts[3])


def test_cust_auth_id(issuer, kyc, rpc):
    '''investor / authority collisions'''
    issuer.addAuthority([accounts[-1]], [], 2000000000, 1, {'from': accounts[0]})
    id_ = issuer.getID(accounts[-1])
    kyc.addInvestor(id_, 1, 1, 1, 9999999999, (accounts[1], accounts[3]), {'from': accounts[0]})
    with pytest.reverts("Address not registered"):
        issuer.getID(accounts[1])
    rpc.revert()
    kyc.addInvestor(id_, 1, 1, 1, 9999999999, (accounts[1], accounts[3]), {'from': accounts[0]})
    issuer.getID.transact(accounts[1])
    with pytest.reverts("dev: known ID"):
        issuer.addAuthority([accounts[-1]], [], 2000000000, 1, {'from': accounts[0]})
