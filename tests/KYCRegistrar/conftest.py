#!/usr/bin/python3

import pytest

from brownie import accounts


@pytest.fixture(scope="module", autouse=True)
def setup(kyc):
    kyc.addAuthority((accounts[-1], accounts[-2]), [1], 1, {'from': accounts[0]})


@pytest.fixture(scope="module")
def owner_id(kyc):
    yield kyc.getAuthorityID(accounts[0])


@pytest.fixture(scope="module")
def auth_id(kyc):
    yield kyc.getAuthorityID(accounts[-1])
