#!/usr/bin/python3

import pytest


@pytest.fixture(scope="module")
def ikyc(KYCIssuer, issuer, accounts):
    kyc = accounts[0].deploy(KYCIssuer, issuer)
    issuer.setRegistrar(kyc, False, {'from': accounts[0]})
    kyc.addInvestor(
        "investor1".encode(),
        1,
        '0x000001',
        1,
        9999999999,
        (accounts[1],),
        {'from': accounts[0]}
    )
    yield kyc
