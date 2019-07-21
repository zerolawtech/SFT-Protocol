#!/usr/bin/python3

import functools
import pytest

from brownie import accounts, rpc

id_ = "investor1".encode()


@pytest.fixture(scope="module", autouse=True)
def setup(issuer, ikyc):
    issuer.addAuthorityAddresses(issuer.ownerID(), accounts[1:3], {'from': accounts[0]})
    issuer.addAuthority(accounts[3:6], [], 2000000000, 1, {'from': accounts[0]})


@pytest.fixture(scope="module")
def multisig(issuer):
    yield functools.partial(_multisig, issuer)


def test_addInvestor(multisig, ikyc):
    multisig(ikyc.addInvestor, "0x1234", 1, 1, 1, 9999999999, (accounts[7],))


def test_updateInvestor(multisig, ikyc):
    multisig(ikyc.updateInvestor, id_, 2, 4, 1234567890)


def test_setInvestorRestriction(multisig, ikyc):
    multisig(ikyc.setInvestorRestriction, id_, False)


def test_registerAddresses(multisig, ikyc):
    multisig(ikyc.registerAddresses, id_, (accounts[7],))


def test_restrictAddresses(multisig, ikyc):
    multisig(ikyc.restrictAddresses, id_, (accounts[1],))


def _multisig(issuer, fn, *args):
    auth_id = issuer.getID(accounts[3])
    args = list(args) + [{'from': accounts[3]}]
    # check for failed call, no permission
    with pytest.reverts("dev: not permitted"):
        fn(*args)
    # give permission and check for successful call
    issuer.setAuthoritySignatures(auth_id, [fn.signature], True, {'from': accounts[0]})
    assert 'MultiSigCallApproved' in fn(*args).events
    rpc.revert()
    # give permission, threhold to 3, check for success and fails
    issuer.setAuthoritySignatures(auth_id, [fn.signature], True, {'from': accounts[0]})
    issuer.setAuthorityThreshold(auth_id, 3, {'from': accounts[0]})
    args[-1]['from'] = accounts[3]
    assert 'MultiSigCallApproved' not in fn(*args).events
    with pytest.reverts("dev: repeat caller"):
        fn(*args)
    args[-1]['from'] = accounts[4]
    assert 'MultiSigCallApproved' not in fn(*args).events
    with pytest.reverts("dev: repeat caller"):
        fn(*args)
    args[-1]['from'] = accounts[5]
    assert 'MultiSigCallApproved' in fn(*args).events
