#!/usr/bin/python3

from brownie import *
from scripts.deployment import main


def setup():
    config['test']['always_transact'] = False
    global kyc, issuer, owner_id, auth_id
    issuer = a[0].deploy(IssuingEntity, a[0:3], 1)
    issuer.addAuthority(a[3:6],[], 2000000000, 1, {'from': a[0]})
    kyc = a[0].deploy(KYCIssuer, issuer)
    issuer.setRegistrar(kyc, True, {'from': a[0]})
    kyc.addInvestor("0x1111", 1, 1, 1, 9999999999, (a[6],), {'from': a[0]})
    owner_id = issuer.ownerID()
    auth_id = issuer.getID(a[3])


# addInvestor
# updateInvestor
# setInvestorRestriction
# registerAddresses
# restrictAddresses

def addInvestor():
    _multisig(kyc.addInvestor, "0x1234", 1, 1, 1, 9999999999, (a[7],))

def updateInvestor():
    _multisig(kyc.updateInvestor, "0x1111", 2, 4, 1234567890)

def setInvestorRestriction():
    _multisig(kyc.setInvestorRestriction,"0x1111", False)

def registerAddresses():
    _multisig(kyc.registerAddresses,"0x1111", (a[7],))

def restrictAddresses():
    _multisig(kyc.restrictAddresses,"0x1111",(a[6],))

def _multisig(fn, *args):
    args = list(args)+[{'from':a[3]}]
    # check for failed call, no permission
    check.reverts(fn, args, "dev: not permitted")
    # give permission and check for successful call
    issuer.setAuthoritySignatures(auth_id, [fn.signature], True, {'from': a[0]})
    check.event_fired(fn(*args),'MultiSigCallApproved')
    rpc.revert()
    # give permission, threhold to 3, check for success and fails
    issuer.setAuthoritySignatures(auth_id, [fn.signature], True, {'from': a[0]})
    issuer.setAuthorityThreshold(auth_id, 3, {'from': a[0]})
    args[-1]['from'] = a[3]
    check.event_not_fired(fn(*args), 'MultiSigCallApproved')
    check.reverts(fn, args, "dev: repeat caller")
    args[-1]['from'] = a[4]
    check.event_not_fired(fn(*args), 'MultiSigCallApproved')
    check.reverts(fn, args, "dev: repeat caller")
    args[-1]['from'] = a[5]
    check.event_fired(fn(*args),'MultiSigCallApproved')
    
    
