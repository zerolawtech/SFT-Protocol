#!/usr/bin/python3

import pytest

from brownie import accounts


@pytest.fixture(scope="module", autouse=True)
def setup(id1, id2, issuer, nft, token):
    for i in range(6):
        accounts.add()
        accounts[0].transfer(accounts[-1], "1 ether")
    issuer.addAuthority(accounts[-6:-3], [], 2000000000, 1, {'from': accounts[0]})
    token.mint(accounts[2], 1000, {'from': accounts[0]})
    nft.mint(accounts[2], 1000, 0, "0x00", {'from': accounts[0]})


def test_token_modifyAuthorizedSupply(multisig, token):
    multisig(token.modifyAuthorizedSupply, 10000)


def test_token_mint(multisig, token):
    multisig(token.mint, accounts[2], 1000)


def test_token_burn(multisig, token):
    multisig(token.burn, accounts[2], 1000)


def test_nft_modifyAuthorizedSupply(multisig, nft):
    multisig(nft.modifyAuthorizedSupply, 10000)


def test_nft_mint(multisig, nft):
    multisig(nft.mint, accounts[2], 1000, 0, "0x00")


def test_nft_burn(multisig, nft):
    multisig(nft.burn, 1, 500)


def test_nft_modifyRange(multisig, nft):
    multisig(nft.modifyRange, 1, 0, "0xff")


def test_nft_modifyRanges(multisig, nft):
    multisig(nft.modifyRanges, 30, 800, 0, "0xff")
