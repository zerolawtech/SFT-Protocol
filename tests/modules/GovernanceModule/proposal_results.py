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
        token.mint(a[i], 1000, {'from': a[0]})
    for i in range(3, 6):
        token2.mint(a[i], 1000, {'from': a[0]})
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


# balances: a[1]    a[2]    a[3]    a[4]    a[4]
# token:    1000    1000    1000    0       0
# token2:   0       0       1000    1000    1000
# token3:   0       0       0       0       1000

def single_vote_no_quorum_pass():
    gov.newVote("0x1234", 6600, 0, [token], [1], {'from': a[0]})
    rpc.sleep(210)
    gov.voteOnProposal("0x1234", 1, {'from': a[1]})
    gov.voteOnProposal("0x1234", 1, {'from': a[2]})
    gov.voteOnProposal("0x1234", 0, {'from': a[3]})
    rpc.sleep(110)
    gov.closeProposal("0x1234", {'from': a[0]})
    check.equal(gov.getProposalState("0x1234"), 5)
    check.equal(gov.getVotePct("0x1234", 0), (6666, 0))


def single_vote_no_quorum_fail():
    gov.newVote("0x1234", 5000, 0, [token], [1], {'from': a[0]})
    rpc.sleep(210)
    gov.voteOnProposal("0x1234", 1, {'from': a[1]})
    gov.voteOnProposal("0x1234", 0, {'from': a[2]})
    gov.voteOnProposal("0x1234", 0, {'from': a[3]})
    rpc.sleep(110)
    gov.closeProposal("0x1234", {'from': a[0]})
    check.equal(gov.getProposalState("0x1234"), 4)
    check.equal(gov.getVotePct("0x1234", 0), (3333, 0))


def single_vote_quorum_pass():
    gov.newVote("0x1234", 5000, 6600, [token], [1], {'from': a[0]})
    rpc.sleep(210)
    gov.voteOnProposal("0x1234", 1, {'from': a[1]})
    gov.voteOnProposal("0x1234", 0, {'from': a[2]})
    rpc.sleep(110)
    gov.closeProposal("0x1234", {'from': a[0]})
    check.equal(gov.getProposalState("0x1234"), 5)
    check.equal(gov.getVotePct("0x1234", 0), (5000, 6666))


def single_vote_quorum_fail():
    gov.newVote("0x1234", 5010, 6600, [token], [1], {'from': a[0]})
    rpc.sleep(210)
    gov.voteOnProposal("0x1234", 1, {'from': a[1]})
    gov.voteOnProposal("0x1234", 0, {'from': a[2]})
    rpc.sleep(110)
    gov.closeProposal("0x1234", {'from': a[0]})
    check.equal(gov.getProposalState("0x1234"), 4)
    check.equal(gov.getVotePct("0x1234", 0), (5000, 6666))


def single_vote_quorum_not_reached():
    gov.newVote("0x1234", 5000, 6700, [token], [1], {'from': a[0]})
    rpc.sleep(210)
    gov.voteOnProposal("0x1234", 1, {'from': a[1]})
    gov.voteOnProposal("0x1234", 0, {'from': a[2]})
    rpc.sleep(110)
    gov.closeProposal("0x1234", {'from': a[0]})
    check.equal(gov.getProposalState("0x1234"), 3)
    check.equal(gov.getVotePct("0x1234", 0), (5000, 6666))


def multi_vote_no_quorum_pass():
    gov.newVote("0x1234", 6600, 0, [token], [1], {'from': a[0]})
    gov.newVote("0x1234", 6600, 0, [token, token2], [1, 2], {'from': a[0]})
    rpc.sleep(210)
    gov.voteOnProposal("0x1234", 0, {'from': a[1]})
    gov.voteOnProposal("0x1234", 1, {'from': a[2]})
    gov.voteOnProposal("0x1234", 1, {'from': a[3]})
    gov.voteOnProposal("0x1234", 1, {'from': a[4]})
    gov.voteOnProposal("0x1234", 0, {'from': a[5]})
    rpc.sleep(110)
    gov.closeProposal("0x1234", {'from': a[0]})
    check.equal(gov.getProposalState("0x1234"), 5)
    check.equal(gov.getVotePct("0x1234", 0), (6666, 0))
    check.equal(gov.getVotePct("0x1234", 1), (6666, 0))


def multi_vote_no_quorum_fail():
    gov.newVote("0x1234", 6600, 0, [token], [1], {'from': a[0]})
    gov.newVote("0x1234", 6700, 0, [token, token2], [1, 2], {'from': a[0]})
    rpc.sleep(210)
    gov.voteOnProposal("0x1234", 0, {'from': a[1]})
    gov.voteOnProposal("0x1234", 1, {'from': a[2]})
    gov.voteOnProposal("0x1234", 1, {'from': a[3]})
    gov.voteOnProposal("0x1234", 1, {'from': a[4]})
    gov.voteOnProposal("0x1234", 0, {'from': a[5]})
    rpc.sleep(110)
    gov.closeProposal("0x1234", {'from': a[0]})
    check.equal(gov.getProposalState("0x1234"), 4)
    check.equal(gov.getVoteResult("0x1234", 0), 5)
    check.equal(gov.getVotePct("0x1234", 0), (6666, 0))
    check.equal(gov.getVoteResult("0x1234", 1), 4)
    check.equal(gov.getVotePct("0x1234", 1), (6666, 0))


def multi_vote_quorum_pass():
    gov.newVote("0x1234", 5000, 6600, [token], [1], {'from': a[0]})
    gov.newVote("0x1234", 5000, 6600, [token, token2], [1, 2], {'from': a[0]})
    rpc.sleep(210)
    gov.voteOnProposal("0x1234", 0, {'from': a[2]})
    gov.voteOnProposal("0x1234", 1, {'from': a[3]})
    gov.voteOnProposal("0x1234", 0, {'from': a[4]})
    rpc.sleep(110)
    gov.closeProposal("0x1234", {'from': a[0]})
    check.equal(gov.getProposalState("0x1234"), 5)
    check.equal(gov.getVotePct("0x1234", 0), (5000, 6666))
    check.equal(gov.getVotePct("0x1234", 1), (5000, 6666))


def multi_vote_quorum_fail():
    gov.newVote("0x1234", 5010, 6600, [token], [1], {'from': a[0]})
    gov.newVote("0x1234", 5000, 6600, [token, token2], [1, 2], {'from': a[0]})
    rpc.sleep(210)
    gov.voteOnProposal("0x1234", 0, {'from': a[2]})
    gov.voteOnProposal("0x1234", 1, {'from': a[3]})
    gov.voteOnProposal("0x1234", 0, {'from': a[4]})
    rpc.sleep(110)
    gov.closeProposal("0x1234", {'from': a[0]})
    check.equal(gov.getProposalState("0x1234"), 4)
    check.equal(gov.getVoteResult("0x1234", 0), 4)
    check.equal(gov.getVoteResult("0x1234", 1), 5)
    check.equal(gov.getVotePct("0x1234", 0), (5000, 6666))
    check.equal(gov.getVotePct("0x1234", 1), (5000, 6666))

def multi_vote_quorum_not_reached():
    gov.newVote("0x1234", 5000, 6600, [token], [1], {'from': a[0]})
    gov.newVote("0x1234", 5000, 6700, [token, token2], [1, 2], {'from': a[0]})
    rpc.sleep(210)
    gov.voteOnProposal("0x1234", 0, {'from': a[2]})
    gov.voteOnProposal("0x1234", 1, {'from': a[3]})
    gov.voteOnProposal("0x1234", 0, {'from': a[4]})
    rpc.sleep(110)
    gov.closeProposal("0x1234", {'from': a[0]})
    check.equal(gov.getProposalState("0x1234"), 3)
    check.equal(gov.getVoteResult("0x1234", 0), 5)
    check.equal(gov.getVoteResult("0x1234", 1), 3)
    check.equal(gov.getVotePct("0x1234", 0), (5000, 6666))
    check.equal(gov.getVotePct("0x1234", 1), (5000, 6666))
