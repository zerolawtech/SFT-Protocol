#!/usr/bin/python3

import functools
import itertools
import pytest

from brownie import accounts
from brownie.convert import to_bytes


# test isolation, always use!

@pytest.fixture(autouse=True)
def isolation(fn_isolation):
    pass


# token deployments / linking

@pytest.fixture(scope="module")
def token(SecurityToken, issuer, accounts):
    t = accounts[0].deploy(SecurityToken, issuer, "Test Token", "TST", 1000000)
    issuer.addToken(t, {'from': accounts[0]})
    yield t


@pytest.fixture(scope="module")
def token2(SecurityToken, issuer, accounts, token):
    t = accounts[0].deploy(SecurityToken, issuer, "Test Token2", "TS2", 1000000)
    issuer.addToken(t, {'from': accounts[0]})
    yield t


@pytest.fixture(scope="module")
def nft(NFToken, issuer, accounts):
    token = accounts[0].deploy(NFToken, issuer, "Test NFT", "NFT", 1000000)
    issuer.addToken(token, {'from': accounts[0]})
    yield token


@pytest.fixture(scope="module")
def issuer(IssuingEntity, accounts):
    issuer = accounts[0].deploy(IssuingEntity, [accounts[0]], 1)
    yield issuer


@pytest.fixture(scope="module")
def kyc(KYCRegistrar, issuer, accounts):
    kyc = accounts[0].deploy(KYCRegistrar, [accounts[0]], 1)
    issuer.setRegistrar(kyc, False, {'from': accounts[0]})
    yield kyc


@pytest.fixture(scope="module")
def cust(OwnedCustodian, accounts, issuer):
    accounts[0].deploy(OwnedCustodian, [accounts[0]], 1)
    issuer.addCustodian(OwnedCustodian[0], {'from': accounts[0]})
    yield OwnedCustodian[0]


# investor approval


@pytest.fixture(scope="module")
def ownerid(issuer):
    yield issuer.ownerID()


@pytest.fixture(scope="module")
def set_countries(issuer):
    issuer.setCountries((1, 2, 3), (1, 1, 1), (0, 0, 0), {'from': accounts[0]})


@pytest.fixture(scope="module")
def id1(set_countries, kyc):
    yield _add_investor(kyc, 1, 1, 1)


@pytest.fixture(scope="module")
def id2(set_countries, kyc):
    yield _add_investor(kyc, 2, 1, 2)


@pytest.fixture(scope="module")
def approve_many(id1, id2, kyc):
    product = list(itertools.product((2, 3), (1, 2)))
    for count, country, rating in [(c, i[0], i[1]) for c, i in enumerate(product, start=3)]:
        _add_investor(kyc, count, country, rating)


def _add_investor(kyc, i, country, rating):
    id_ = to_bytes(f"investor{i}".encode()).hex()
    kyc.addInvestor(
        id_,
        country,
        '0x000001',
        rating,
        9999999999,
        (accounts[i],),
        {'from': accounts[0]}
    )
    return id_


@pytest.fixture
def check_counts(issuer, approve_many, no_call_coverage):
    yield functools.partial(_check_countries, issuer)


def _check_countries(issuer, one=(0, 0, 0), two=(0, 0, 0), three=(0, 0, 0)):
    assert issuer.getInvestorCounts()[0][:3] == (
        one[0] + two[0] + three[0],
        one[1] + two[1] + three[1],
        one[2] + two[2] + three[2]
    )
    assert issuer.getCountry(1)[1][:3] == one
    assert issuer.getCountry(2)[1][:3] == two
    assert issuer.getCountry(3)[1][:3] == three
