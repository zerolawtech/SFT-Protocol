#!/usr/bin/python3

from brownie import *
from scripts.deployment import deploy_contracts

proposal_inputs = ["0x1234", 1500000000, 2000000000, 2100000000, "test proposal", "0" * 40, "0x"]


def setup():
    global token, issuer, cp, gov
    token, issuer, _ = deploy_contracts(SecurityToken)
    cp = a[0].deploy(MultiCheckpointModule, issuer)
    issuer.attachModule(token, cp, {'from': a[0]})
    gov = a[0].deploy(GovernanceModule, issuer, cp)
    issuer.setGovernance(gov, {'from': a[0]})
    proposal_inputs.append({'from': a[0]})


def new_proposal():
    gov.newProposal(*proposal_inputs)


def new_proposal_no_end():
    p = proposal_inputs.copy()
    p[3] = 0
    gov.newProposal(*proposal_inputs)


def new_proposal_exists():
    gov.newProposal(*proposal_inputs)
    check.reverts(gov.newProposal, proposal_inputs, "dev: proposal already exists")


def new_proposal_start_before_now():
    p = proposal_inputs.copy()
    p[2] = 151000000
    check.reverts(gov.newProposal, p, "dev: start < now")


def new_proposal_start_before_cp():
    p = proposal_inputs.copy()
    p[1] = 2100000000
    check.reverts(gov.newProposal, p, "dev: start < checkpoint")


def new_proposal_end_before_start():
    p = proposal_inputs.copy()
    p[3] = 190000000
    check.reverts(gov.newProposal, p, "dev: end < start")
