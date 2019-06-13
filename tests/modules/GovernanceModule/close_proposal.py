#!/usr/bin/python3

import time

from brownie import *
from scripts.deployment import main

cptime = int(time.time() + 100)


def setup():
    global token, token2, token3, issuer, cp, gov
    token, issuer, _ = main(SecurityToken, (1, 2, 3, 4, 5), (1,))
    token2 = a[0].deploy(SecurityToken, issuer, "", "", 1000000)
    issuer.addToken(token2, {'from': a[0]})
    token3 = a[0].deploy(SecurityToken, issuer, "", "", 1000000)
    issuer.addToken(token3, {'from': a[0]})
    cp = a[0].deploy(MultiCheckpointModule, issuer)
    for i in range(1, 4):
        token.mint(a[i], 1000 * i, {'from': a[0]})
    for i in range(3, 6):
        token2.mint(a[i], 1000 * i, {'from': a[0]})
    token3.mint(a[5], 1000, {'from': a[0]})
    issuer.attachModule(token, cp, {'from': a[0]})
    cp.newCheckpoint(token, cptime, {'from': a[0]})
    issuer.attachModule(token2, cp, {'from': a[0]})
    cp.newCheckpoint(token2, cptime, {'from': a[0]})
    issuer.attachModule(token3, cp, {'from': a[0]})
    cp.newCheckpoint(token3, cptime, {'from': a[0]})
    gov = a[0].deploy(GovernanceModule, issuer, cp)
    issuer.setGovernance(gov, {'from': a[0]})
    gov.newProposal(
        "0x1234",
        cptime,
        cptime + 100,
        cptime + 200,
        "test proposal",
        "0" * 40,
        "0x",
        {'from': a[0]}
    )
    gov.newVote("0x1234", 5000, 0, [token], [1], {'from': a[0]})
    gov.newVote("0x1234", 5000, 0, [token, token2], [1, 2], {'from': a[0]})


def close_proposal():
    rpc.sleep(210)
    gov.voteOnProposal("0x1234", 1, {'from': a[1]})
    rpc.sleep(110)
    gov.closeProposal("0x1234", {'from': a[0]})


def close_proposal_no_votes():
    rpc.sleep(310)
    gov.closeProposal("0x1234", {'from': a[0]})


def close_proposal_not_ended():
    check.reverts(
        gov.closeProposal,
        ("0x1234", {'from': a[0]}),
        "dev: voting has not finished"
    )


def close_proposal_invalid_id():
    check.reverts(
        gov.closeProposal,
        ("0x1111", {'from': a[0]}),
        "dev: proposal not active"
    )


def close_proposal_already_closed():
    rpc.sleep(310)
    gov.closeProposal("0x1234", {'from': a[0]})
    check.reverts(
        gov.closeProposal,
        ("0x1234", {'from': a[0]}),
        "dev: proposal not active"
    )


def close_proposal_no_end_not_passing():
    gov.newProposal(
        "0xffff",
        cptime,
        cptime + 100,
        0,
        "test proposal",
        "0" * 40,
        "0x",
        {'from': a[0]}
    )
    gov.newVote("0xffff", 5000, 0, [token3], [1], {'from': a[0]})
    rpc.sleep(210)
    check.reverts(
        gov.closeProposal,
        ("0xffff", {'from': a[0]}),
        "dev: proposal has not passed"
    )


def close_proposal_no_end_passing():
    gov.newProposal(
        "0xffff",
        cptime,
        cptime + 100,
        0,
        "test proposal",
        "0" * 40,
        "0x",
        {'from': a[0]}
    )
    gov.newVote("0xffff", 5000, 0, [token3], [1], {'from': a[0]})
    rpc.sleep(210)
    gov.voteOnProposal("0xffff", 1, {'from': a[5]})
    gov.closeProposal("0xffff", {'from': a[0]})
