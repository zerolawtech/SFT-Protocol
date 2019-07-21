#!/usr/bin/python3

import functools
import pytest

from brownie import accounts, rpc


@pytest.fixture(scope="module", autouse=True)
def local_setup(kyc, owner_id, auth_id):
    kyc.setAuthorityCountries(auth_id, (1,), False, {'from': accounts[0]})
    kyc.registerAddresses(owner_id, accounts[1:5], {'from': accounts[0]})
    kyc.registerAddresses(auth_id, accounts[-5:-2], {'from': accounts[0]})
    kyc.addInvestor("0x1111", 1, 1, 1, 9999999999, (accounts[5],), {'from': accounts[0]})


@pytest.fixture(scope="module")
def msowner(kyc, owner_id):
    yield functools.partial(_owner_multisig, kyc, owner_id)


@pytest.fixture(scope="module")
def msauth(kyc, auth_id):
    yield functools.partial(_auth_multisig, kyc, auth_id)


def test_addAuthority(msowner, kyc):
    msowner(kyc.addAuthority, (accounts[6], accounts[7]), [], 1)


def test_setAuthorityThreshold(msowner, kyc, auth_id):
    msowner(kyc.setAuthorityThreshold, auth_id, 2)


def test_setAuthorityCountries(msowner, kyc, auth_id):
    msowner(kyc.setAuthorityCountries, auth_id, (1, 5, 7), True)


def test_setAuthorityRestriction(msowner, kyc, auth_id):
    msowner(kyc.setAuthorityRestriction, auth_id, True)


def test_setInvestorAuthority(msowner, kyc, auth_id):
    msowner(kyc.setInvestorAuthority, auth_id, ("0x1111",))


def test_addInvestor(msauth, kyc):
    msauth(kyc.addInvestor, "0x1234", 1, 1, 1, 9999999999, (accounts[6],))


def test_updateInvestor(msauth, kyc):
    msauth(kyc.updateInvestor, "0x1111", 2, 4, 1234567890)


def test_setInvestorRestriction(msauth, kyc):
    msauth(kyc.setInvestorRestriction, "0x1111", True)


def test_registerAddresses(msauth, kyc):
    msauth(kyc.registerAddresses, "0x1111", (accounts[6],))


def test_restrictAddresses(msauth, kyc):
    msauth(kyc.restrictAddresses, "0x1111", (accounts[5],))


def _auth_multisig(kyc, auth_id, fn, *args):
    args = list(args) + [{'from': accounts[-1]}]
    with pytest.reverts("dev: country"):
        fn(*args)
    kyc.setAuthorityCountries(auth_id, (1,), True, {'from': accounts[0]})
    kyc.setAuthorityThreshold(auth_id, 3, {'from': accounts[0]})
    assert 'MultiSigCallApproved' not in fn(*args).events
    with pytest.reverts("dev: repeat caller"):
        fn(*args)
    args[-1]['from'] = accounts[-2]
    assert 'MultiSigCallApproved' not in fn(*args).events
    with pytest.reverts("dev: repeat caller"):
        fn(*args)
    args[-1]['from'] = accounts[-3]
    assert 'MultiSigCallApproved' in fn(*args).events


def _owner_multisig(kyc, owner_id, fn, *args):
    args = list(args) + [{'from': accounts[0]}]
    with pytest.reverts("dev: only owner"):
        fn(*args[:-1] + [{'from': accounts[-1]}])
    assert 'MultiSigCallApproved' in fn(*args).events
    rpc.revert()
    kyc.setAuthorityThreshold(owner_id, 3, {'from': accounts[0]})
    assert 'MultiSigCallApproved' not in fn(*args).events
    with pytest.reverts("dev: repeat caller"):
        fn(*args)
    args[-1]['from'] = accounts[1]
    assert 'MultiSigCallApproved' not in fn(*args).events
    with pytest.reverts("dev: repeat caller"):
        fn(*args)
    args[-1]['from'] = accounts[2]
    assert 'MultiSigCallApproved' in fn(*args).events
