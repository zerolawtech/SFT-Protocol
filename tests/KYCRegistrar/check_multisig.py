#!/usr/bin/python3

from brownie import *


def setup():
    global kyc, issuer, auth_id, owner_id
    kyc = a[0].deploy(KYCRegistrar, a[0:5], 1)
    owner_id = kyc.getAuthorityID(a[0])
    kyc.addAuthority(a[-5:], [], 1, {'from': a[0]})
    auth_id = kyc.getAuthorityID(a[-1])
    kyc.addInvestor("0x1111", 1, 1, 1, 9999999999, (a[5],), {'from': a[0]})


def addAuthority():
    _owner_multisig(kyc.addAuthority,(a[6], a[7]), [], 1)

def setAuthorityThreshold():
    _owner_multisig(kyc.setAuthorityThreshold, auth_id, 2)

def setAuthorityCountries():
    _owner_multisig(kyc.setAuthorityCountries, auth_id, (1,5,7), True)

def setAuthorityRestriction():
    _owner_multisig(kyc.setAuthorityRestriction, auth_id, True)

def setInvestorAuthority():
    _owner_multisig(kyc.setInvestorAuthority, auth_id, ("0x1111",))

def addInvestor():
    _auth_multisig(kyc.addInvestor, "0x1234", 1, 1, 1, 9999999999, (a[6],))

def updateInvestor():
    _auth_multisig(kyc.updateInvestor, "0x1111", 2, 4, 1234567890)

def setInvestorRestriction():
    _auth_multisig(kyc.setInvestorRestriction, "0x1111", True)

def registerAddresses():
    _auth_multisig(kyc.registerAddresses, "0x1111", (a[6],))

def restrictAddresses():
    _auth_multisig(kyc.restrictAddresses, "0x1111", (a[5],))


def _auth_multisig(fn, *args):
    args = list(args)+[{'from': a[-1]}]
    check.reverts(fn, args, "dev: country")
    kyc.setAuthorityCountries(auth_id, (1,), True, {'from': a[0]})
    kyc.setAuthorityThreshold(auth_id, 3, {'from': a[0]})
    check.event_not_fired(fn(*args), 'MultiSigCallApproved')
    check.reverts(fn, args, "dev: repeat caller")
    args[-1]['from'] = a[-2]
    check.event_not_fired(fn(*args), 'MultiSigCallApproved')
    check.reverts(fn, args, "dev: repeat caller")
    args[-1]['from'] = a[-3]
    check.event_fired(fn(*args), 'MultiSigCallApproved')


def _owner_multisig(fn, *args):
    args = list(args)+[{'from': a[0]}]
    check.reverts(fn, args[:-1]+[{'from': a[-1]}], "dev: only owner")
    check.event_fired(fn(*args), 'MultiSigCallApproved')
    rpc.revert()
    kyc.setAuthorityThreshold(owner_id, 3, {'from': a[0]})
    check.event_not_fired(fn(*args), 'MultiSigCallApproved')
    check.reverts(fn, args, "dev: repeat caller")
    args[-1]['from'] = a[1]
    check.event_not_fired(fn(*args), 'MultiSigCallApproved')
    check.reverts(fn, args, "dev: repeat caller")
    args[-1]['from'] = a[2]
    check.event_fired(fn(*args), 'MultiSigCallApproved')
    
    
    
