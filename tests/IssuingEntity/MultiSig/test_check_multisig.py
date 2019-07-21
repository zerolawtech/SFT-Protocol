#!/usr/bin/python3

import pytest

from brownie import accounts


@pytest.fixture(scope="module", autouse=True)
def setup(issuer):
    for i in range(6):
        accounts.add()
        accounts[0].transfer(accounts[-1], "1 ether")
    issuer.addAuthority(accounts[-6:-3], [], 2000000000, 1, {'from': accounts[0]})


@pytest.fixture(scope="module")
def cust(OwnedCustodian):
    yield accounts[0].deploy(OwnedCustodian, [accounts[0]], 1)


@pytest.fixture(scope="module")
def token2(SecurityToken, issuer):
    yield accounts[0].deploy(SecurityToken, issuer, "Test Token2", "TS2", 1000000)


def test_setCountry(multisig, issuer):
    multisig(issuer.setCountry, 1, True, 1, [0] * 8)


def test_setCountries(multisig, issuer):
    multisig(issuer.setCountries, [1, 2], [1, 1], [0, 0])


def test_setInvestorLimits(multisig, issuer):
    multisig(issuer.setInvestorLimits, [0] * 8)


def test_setDocumentHash(multisig, issuer):
    multisig(issuer.setDocumentHash, "blah blah", "0x1234")


def test_setRegistrar(multisig, issuer):
    multisig(issuer.setRegistrar, accounts[9], False)


def test_addCustodian(multisig, issuer, cust):
    multisig(issuer.addCustodian, cust)


def test_addToken(multisig, issuer, token2):
    multisig(issuer.addToken, token2)


def test_setEntityRestriction(multisig, issuer):
    multisig(issuer.setEntityRestriction, "0x11", True)


def test_setTokenRestriction(multisig, issuer, token):
    multisig(issuer.setTokenRestriction, token, False)


def test_setGlobalRestriction(multisig, issuer):
    multisig(issuer.setGlobalRestriction, True)
