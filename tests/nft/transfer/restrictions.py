#!/usr/bin/python3

from brownie import *
from scripts.deployment import main


def setup():
    main(NFToken)
    global token, issuer, kyc
    token = NFToken[0]
    issuer = IssuingEntity[0]
    kyc = KYCRegistrar[0]
    token.mint(issuer, 1000000, 0, "0x00", {'from': a[0]})

def sender_restricted():
    '''sender restricted - investor / investor'''
    id_ = kyc.getID(a[1])
    token.transfer(a[1], 1000, {'from': a[0]})
    issuer.setEntityRestriction(id_, False, {'from': a[0]})
    check.reverts(
        token.transfer,
        (a[2], 1000, {'from': a[1]}),
        "Sender restricted: Issuer"
    )
    issuer.setEntityRestriction(id_, True, {'from': a[0]})
    token.transfer(a[2], 1000, {'from': a[1]})

def sender_restricted_issuer():
    '''sender restricted - issuer / investor'''
    check.reverts(
        issuer.setEntityRestriction,
        (issuer.ownerID(), False, {'from': a[0]}),
        "dev: authority"
    )
    issuer.addAuthorityAddresses(issuer.ownerID(), [a[-1]], {'from':a[0]})
    token.transfer(a[1], 1000, {'from': a[-1]})
    issuer.removeAuthorityAddresses(issuer.ownerID(), [a[-1]], {'from':a[0]})
    check.reverts(
        token.transfer,
        (a[1], 1000, {'from': a[-1]}),
        "Restricted Authority Address"
    )
    issuer.addAuthorityAddresses(issuer.ownerID(), [a[-1]], {'from':a[0]})
    token.transfer(a[1], 1000, {'from': a[-1]})

def sender_restricted_kyc_id():
    '''sender ID restricted at kyc'''
    token.transfer(a[1], 1000, {'from': a[0]})
    kyc.setInvestorRestriction(kyc.getID(a[1]), False, {'from':a[0]})
    check.reverts(
        token.transfer,
        (a[2], 1000, {'from': a[1]}),
        "Sender restricted: Registrar"
    )

def sender_restricted_kyc_addr():
    '''sender address restricted at kyc'''
    token.transfer(a[1], 1000, {'from': a[0]})
    kyc.restrictAddresses(kyc.getID(a[1]), [a[1]], {'from':a[0]})
    check.reverts(
        token.transfer,
        (a[2], 1000, {'from': a[1]}),
        "Sender restricted: Registrar"
    )

def receiver_restricted_issuer():
    '''receiver restricted'''
    issuer.setEntityRestriction(issuer.getID(a[1]), False, {'from': a[0]})
    check.reverts(
        token.transfer,
        (a[1], 1000, {'from': a[0]}),
        "Receiver restricted: Issuer"
    )

def receiver_restricted_kyc_id():
    '''receiver ID restricted at kyc'''
    kyc.setInvestorRestriction(kyc.getID(a[1]), False, {'from':a[0]})
    check.reverts(
        token.transfer,
        (a[1], 1000, {'from': a[0]}),
        "Receiver restricted: Registrar"
    )

def receiver_restricted_kyc_addr():
    '''receiver address restricted at kyc'''
    kyc.restrictAddresses(kyc.getID(a[1]), [a[1]], {'from':a[0]})
    check.reverts(
        token.transfer,
        (a[1], 1000, {'from': a[0]}),
        "Receiver restricted: Registrar"
    )

def authority_permission():
    '''authority transfer permission'''
    tx = issuer.addAuthority([a[-1]], ["0xa9059cbb"], 2000000000, 1, {'from':a[0]})
    token.transfer(a[1], 1000, {'from': a[-1]})
    issuer.setAuthoritySignatures(issuer.getID(a[-1]), ["0xa9059cbb"], False, {'from':a[0]})
    check.reverts(
        token.transfer,
        (a[1], 1000, {'from': a[-1]}),
        "Authority not permitted"
    )
    token.transfer(a[-1], 100, {'from': a[1]})


def receiver_blocked_rating():
    '''receiver blocked - rating'''
    issuer.setCountry(1, True, 3, [0]*8, {'from':a[0]})
    check.reverts(
        token.transfer,
        (a[1], 1000, {'from': a[0]}),
        "Receiver blocked: Rating"
    )

def receiver_blocked_country():
    '''receiver blocked - country'''
    issuer.setCountry(1, False, 1, [0]*8, {'from':a[0]})
    check.reverts(
        token.transfer,
        (a[1], 1000, {'from': a[0]}),
        "Receiver blocked: Country"
    )