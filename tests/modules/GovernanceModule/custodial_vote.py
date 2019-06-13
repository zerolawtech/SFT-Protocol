#!/usr/bin/python3

import time

from brownie import *
from scripts.deployment import main, deploy_custodian

cptime = int(time.time() + 100)


def setup():
    global token, token2, token3, issuer, cp, gov, cust
    token, issuer, _ = main(SecurityToken, (1, 2, 3, 4, 5), (1,))
    cust = deploy_custodian()
    token2 = a[0].deploy(SecurityToken, issuer, "", "", 1000000)
    issuer.addToken(token2, {'from': a[0]})
    token3 = a[0].deploy(SecurityToken, issuer, "", "", 1000000)
    issuer.addToken(token3, {'from': a[0]})
    cp = a[0].deploy(MultiCheckpointModule, issuer)
    for i in range(1, 4):
        token.mint(a[i], 1000 * i, {'from': a[0]})
        token.transfer(cust, 500, {'from': a[i]})
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


def vote():
    rpc.sleep(210)
    gov.voteOnProposal("0x1234", 1, {'from': a[1]})
    gov.custodialVoteOnProposal("0x1234", cust, {'from': a[1]})
    gov.voteOnProposal("0x1234", 1, {'from': a[4]})
    gov.custodialVoteOnProposal("0x1234", cust, {'from': a[4]})
    gov.voteOnProposal("0x1234", 1, {'from': a[8]})
    gov.custodialVoteOnProposal("0x1234", cust, {'from': a[8]})


def vote_invalid():
    check.reverts(
        gov.custodialVoteOnProposal,
        ("0x1111", cust, {'from': a[1]}),
        "dev: proposal not active"
    )


def vote_ended():
    rpc.sleep(210)
    gov.voteOnProposal("0x1234", 1, {'from': a[1]})
    rpc.sleep(110)
    check.reverts(
        gov.custodialVoteOnProposal,
        ("0x1234", cust, {'from': a[1]}),
        "dev: voting has finished"
    )


def custodial_has_not_voted():
    rpc.sleep(210)
    gov.voteOnProposal("0x1234", 1, {'from': a[2]})
    check.reverts(
        gov.custodialVoteOnProposal,
        ("0x1234", cust, {'from': a[1]}),
        "dev: has not voted"
    )


def custodial_already_voted():
    rpc.sleep(210)
    gov.voteOnProposal("0x1234", 1, {'from': a[1]})
    gov.custodialVoteOnProposal("0x1234", cust, {'from': a[1]})
    check.reverts(
        gov.custodialVoteOnProposal,
        ("0x1234", cust, {'from': a[1]}),
        "dev: has voted with custodian"
    )
