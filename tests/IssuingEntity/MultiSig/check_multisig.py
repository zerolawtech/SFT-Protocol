#!/usr/bin/python3

from brownie import *
from scripts.deployment import deploy_contracts


def setup():
    global token, issuer, ownerid, id1
    token, issuer, _ = deploy_contracts(SecurityToken)

    a[0].deploy(SecurityToken, issuer, "Test", "TST", 1000000)
    a[0].deploy(OwnedCustodian, [a[0]], 1)
    for i in range(6):
        a.add()
        a[0].transfer(a[-1], "1 ether")
    issuer.addAuthority(a[-6:-3],[], 2000000000, 1, {'from': a[0]})
    ownerid = issuer.ownerID()
    id1 = issuer.getID(a[-6])

def setCountry():
    _multisig(issuer.setCountry, 1, True, 1, [0]*8)

def setCountries():
    _multisig(issuer.setCountries, [1,2], [1,1], [0,0])

def setInvestorLimits():
    _multisig(issuer.setInvestorLimits, [0]*8)

def setDocumentHash():
    _multisig(issuer.setDocumentHash, "blah blah", "0x1234")

def setRegistrar():
    _multisig(issuer.setRegistrar, a[9], False)

def addCustodian():
    _multisig(issuer.addCustodian, OwnedCustodian[0])

def addToken():
    _multisig(issuer.addToken, SecurityToken[1])

def setEntityRestriction():
    _multisig(issuer.setEntityRestriction, "0x11", True)

def setTokenRestriction():
    _multisig(issuer.setTokenRestriction, token, False)

def setGlobalRestriction():
    _multisig(issuer.setGlobalRestriction, True)

def attachModule(skip=True):
    _multisig(issuer.attachModule)

def detachModule(skip=True):
    _multisig(issuer.detachModule)

def _multisig(fn, *args):
    args = list(args)+[{'from':a[-6]}]
    # check for failed call, no permission
    check.reverts(fn, args, "dev: not permitted")
    # give permission and check for successful call
    issuer.setAuthoritySignatures(id1, [fn.signature], True, {'from': a[0]})
    check.event_fired(fn(*args),'MultiSigCallApproved')
    rpc.revert()
    # give permission, threhold to 3, check for success and fails
    issuer.setAuthoritySignatures(id1, [fn.signature], True, {'from': a[0]})
    issuer.setAuthorityThreshold(id1, 3, {'from': a[0]})
    args[-1]['from'] = a[-6]
    check.event_not_fired(fn(*args), 'MultiSigCallApproved')
    check.reverts(fn, args, "dev: repeat caller")
    args[-1]['from'] = a[-5]
    check.event_not_fired(fn(*args), 'MultiSigCallApproved')
    check.reverts(fn, args, "dev: repeat caller")
    args[-1]['from'] = a[-4]
    check.event_fired(fn(*args),'MultiSigCallApproved')
    
    
