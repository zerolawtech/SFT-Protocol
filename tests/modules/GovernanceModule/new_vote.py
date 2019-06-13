#!/usr/bin/python3

import time

from brownie import *
from scripts.deployment import deploy_contracts

cptime = int(time.time() + 100)


def setup():
    global token, token2, token3, issuer, cp, gov
    token, issuer, _ = deploy_contracts(SecurityToken)
    token2 = a[0].deploy(SecurityToken, issuer, "", "", 1000000)
    issuer.addToken(token2, {'from': a[0]})
    token3 = a[0].deploy(SecurityToken, issuer, "", "", 1000000)
    issuer.addToken(token3, {'from': a[0]})
    cp = a[0].deploy(MultiCheckpointModule, issuer)
    issuer.attachModule(token, cp, {'from': a[0]})
    cp.newCheckpoint(token, cptime, {'from': a[0]})
    issuer.attachModule(token2, cp, {'from': a[0]})
    cp.newCheckpoint(token2, cptime, {'from': a[0]})
    issuer.attachModule(token3, cp, {'from': a[0]})
    cp.newCheckpoint(token3, cptime + 50, {'from': a[0]})
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


def new_vote():
    gov.newVote("0x1234", 5000, 0, [token, token2], [1, 2], {'from': a[0]})


def new_vote_wrong_state():
    check.reverts(
        gov.newVote,
        ("0x1111", 5000, 0, [token, token2], [1, 2], {'from': a[0]}),
        "dev: wrong state"
    )


def new_vote_no_tokens():
    check.reverts(
        gov.newVote,
        ("0x1234", 5000, 0, [], [], {'from': a[0]}),
        "dev: empty token array"
    )


def new_vote_mismatch():
    check.reverts(
        gov.newVote,
        ("0x1234", 5000, 0, [token, token2], [1, 2, 3], {'from': a[0]}),
        "dev: array length mismatch"
    )


def new_vote_required_pct():
    check.reverts(
        gov.newVote,
        ("0x1234", 11000, 0, [token, token2], [1, 2], {'from': a[0]}),
        "dev: required pct too high"
    )


def new_vote_quorum_pct():
    check.reverts(
        gov.newVote,
        ("0x1234", 5000, 11000, [token, token2], [1, 2], {'from': a[0]}),
        "dev: quorum pct too high"
    )


def new_vote_repeat_token():
    check.reverts(
        gov.newVote,
        ("0x1234", 5000, 0, [token, token], [1, 2], {'from': a[0]}),
        "dev: token repeat"
    )


def new_vote_no_checkpoint():
    check.reverts(
        gov.newVote,
        ("0x1234", 5000, 0, [token, token3], [1, 2], {'from': a[0]}),
        "dev: no checkpoint"
    )
