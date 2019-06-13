#!/usr/bin/python3

import time

from brownie import *
from scripts.deployment import main

cptime = int(time.time() + 100)


def setup():
    global token, token2, token3, issuer, gov
    token, issuer, _ = main(SecurityToken, (1,), (1,))
    token2 = a[0].deploy(SecurityToken, issuer, "", "", 1000000)
    issuer.addToken(token2, {'from': a[0]})
    cp = a[0].deploy(MultiCheckpointModule, issuer)
    token.mint(a[1], 10000, {'from': a[0]})
    issuer.attachModule(token, cp, {'from': a[0]})
    cp.newCheckpoint(token, cptime, {'from': a[0]})
    issuer.attachModule(token2, cp, {'from': a[0]})
    cp.newCheckpoint(token2, cptime, {'from': a[0]})
    gov = a[0].deploy(GovernanceModule, issuer, cp)
    issuer.setGovernance(gov, {'from': a[0]})
    token3 = a[0].deploy(SecurityToken, issuer, "", "", 1000000)


def modify_authorized_supply_not_approved():
    check.reverts(
        token.modifyAuthorizedSupply,
        (200000000, {'from': a[0]})
    )


def modify_authorized_supply_approved():
    _proposal(gov.modifyAuthorizedSupply.encode_abi(token, 200000000))
    # wrong token
    check.reverts(
        token2.modifyAuthorizedSupply,
        (200000000, {'from': a[0]})
    )
    # wrong amount
    check.reverts(
        token.modifyAuthorizedSupply,
        (190000000, {'from': a[0]})
    )
    token.modifyAuthorizedSupply(200000000, {'from': a[0]})
    # call is only approved once
    check.reverts(
        token.modifyAuthorizedSupply,
        (200000000, {'from': a[0]})
    )


def add_token_not_approved():
    check.reverts(
        issuer.addToken,
        (token3, {'from': a[0]})
    )


def add_token_approved():
    _proposal(gov.addToken.encode_abi(token3))
    token4 = a[0].deploy(SecurityToken, issuer, "", "", 1000000)
    # wrong token
    check.reverts(
        issuer.addToken,
        (token4, {'from': a[0]})
    )
    issuer.addToken(token3, {'from': a[0]})


def _proposal(approval_abi):
    gov.newProposal(
        "0xffff",
        cptime,
        cptime + 100,
        0,
        "test proposal",
        issuer,
        approval_abi,
        {'from': a[0]}
    )
    gov.newVote("0xffff", 5000, 0, [token], [1], {'from': a[0]})
    rpc.sleep(210)
    gov.voteOnProposal("0xffff", 1, {'from': a[1]})
    gov.closeProposal("0xffff", {'from': a[0]})
