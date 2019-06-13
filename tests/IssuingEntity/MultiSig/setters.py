#!/usr/bin/python3

from brownie import *
from scripts.deployment import deploy_contracts


def setup():
    global token, issuer, ownerid, id1, id2
    token, issuer, _ = deploy_contracts(SecurityToken)
    for i in range(10):
        a.add()
    sigs = (
        issuer.signatures['setAuthoritySignatures'],
        issuer.signatures['setAuthorityApprovedUntil'],
        issuer.signatures['setAuthorityThreshold']
    )
    issuer.addAuthority((a[-2],), sigs, 2000000000, 1, {'from': a[0]})
    issuer.addAuthority((a[-1], a[-3]), sigs, 2000000000, 1, {'from': a[0]})
    for i in range(-3,0):
        a[0].transfer(a[i], "1 ether")
    ownerid = issuer.ownerID()
    id1 = issuer.getID(a[-2])
    id2 =issuer.getID(a[-1])


def set_approval():
    '''set authrority approved until'''
    issuer.setAuthorityApprovedUntil(id1, 12345, {'from': a[0]})
    check.equal(issuer.getAuthority(id1), (1, 1, 12345))
    issuer.setAuthorityApprovedUntil(id1, 0, {'from': a[0]})
    check.equal(issuer.getAuthority(id1), (1, 1, 0))
    issuer.setAuthorityApprovedUntil(id1, 2000000000, {'from': a[0]})
    check.equal(issuer.getAuthority(id1), (1, 1, 2000000000))

def set_approval_as_authority():
    '''set authority approved until - as authority (reverts)'''
    check.reverts(
        issuer.setAuthorityApprovedUntil,
        (id1, 12345, {'from': a[-2]})
    )

def set_signatures():
    '''set authority signatures'''
    sigs = (
        issuer.signatures['addAuthorityAddresses'],
        issuer.signatures['removeAuthorityAddresses']
    )
    check.false(issuer.isApprovedAuthority(a[-2], sigs[0]))
    check.false(issuer.isApprovedAuthority(a[-2], sigs[1]))
    issuer.setAuthoritySignatures(id1, sigs, True, {'from': a[0]})
    check.true(issuer.isApprovedAuthority(a[-2], sigs[0]))
    check.true(issuer.isApprovedAuthority(a[-2], sigs[1]))
    issuer.setAuthoritySignatures(id1, sigs, False, {'from': a[0]})
    check.false(issuer.isApprovedAuthority(a[-2], sigs[0]))
    check.false(issuer.isApprovedAuthority(a[-2], sigs[1]))


def set_sigs_as_authority():
    '''set authority signatures - as authority (reverts)'''
    check.reverts(
        issuer.setAuthoritySignatures,
        (id1, (issuer.signatures['setAuthoritySignatures'],), True, {'from': a[-2]})
    )


def set_threshold():
    '''set threshold'''
    issuer.setAuthorityThreshold(id2, 2, {'from': a[0]})
    check.equal(issuer.getAuthority(id2), (2, 2, 2000000000))
    issuer.setAuthorityThreshold(id2, 1, {'from': a[0]})
    check.equal(issuer.getAuthority(id2), (2, 1, 2000000000))


def set_threshold_as_authority():
    '''set threshold as authority'''
    issuer.setAuthorityThreshold(id2, 2, {'from': a[-1]})
    check.equal(issuer.getAuthority(id2), (2, 2, 2000000000))
    issuer.setAuthorityThreshold(id2, 1, {'from': a[-1]})
    check.equal(issuer.getAuthority(id2), (2, 2, 2000000000))
    issuer.setAuthorityThreshold(id2, 1, {'from': a[-3]})
    check.equal(issuer.getAuthority(id2), (2, 1, 2000000000))


def set_threshold_as_authority_not_permitted():
    '''set threshold as authority, not permitted'''
    issuer.setAuthoritySignatures(id2, (issuer.signatures['setAuthorityThreshold'],), False, {'from': a[0]})
    check.reverts(
        issuer.setAuthorityThreshold,
        (id2, 2, {'from': a[-1]})
    )
    issuer.setAuthoritySignatures(id2, (issuer.signatures['setAuthorityThreshold'],), True, {'from': a[0]})
    issuer.setAuthorityThreshold(id2, 2, {'from': a[-1]})


def set_other_authority_threshold():
    '''set other authority threshold (reverts)'''
    check.reverts(
        issuer.setAuthorityThreshold,
        (id1, 1, {'from': a[-1]}),
        "dev: wrong authority"
    )


def set_threshold_too_high():
    '''set threshold too high'''
    check.reverts(
        issuer.setAuthorityThreshold,
        (id1, 2, {'from': a[-2]}),
        "dev: threshold too high"
    )


