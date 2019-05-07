#!/usr/bin/python3

from brownie import *
from scripts.deployment import main


def setup():
    global token, issuer, kyc, kyc2
    kyc = a[0].deploy(KYCRegistrar, [a[0]], 1)
    kyc2 = a[0].deploy(KYCRegistrar, [a[0]], 1)
    issuer = a[0].deploy(IssuingEntity, [a[0]], 1)
    token = a[0].deploy(SecurityToken, issuer, "Test", "TST", 1000000)
    issuer.addToken(token, {'from': a[0]})
    issuer.setRegistrar(kyc, True, {'from': a[0]})
    issuer.setRegistrar(kyc2, True, {'from': a[0]})
    token.mint(issuer, 1000000, {'from': a[0]})


def unknown_address():
    '''unknown address'''
    issuer.getID(a[0])
    check.reverts(issuer.getID, (a[1],), "Address not registered")


def registrar_restricted():
    '''registrar restricted'''
    kyc.addInvestor("0x1234", 1, 1, 1, 9999999999, (a[1],), {'from': a[0]})
    issuer.getID.transact(a[1])
    issuer.setRegistrar(kyc, False, {'from': a[0]})
    check.reverts(issuer.getID, (a[1],), "Registrar restricted")


def different_registrar():
    '''multiple registrars, different addresses'''
    kyc.addInvestor("0x1234", 1, 1, 1, 9999999999, (a[1],a[3]), {'from': a[0]})
    kyc2.addInvestor("0x1234", 1, 1, 1, 9999999999, (a[1],a[2]), {'from': a[0]})
    issuer.getID.transact(a[1])
    check.reverts(issuer.getID, (a[2],), "Address not registered")
    issuer.getID.transact(a[3])


def restrict_registrar():
    '''change registrar'''
    kyc.addInvestor("0x1234", 1, 1, 1, 9999999999, (a[1],a[3]), {'from': a[0]})
    kyc2.addInvestor("0x1234", 1, 1, 1, 9999999999, (a[1],a[2]), {'from': a[0]})
    issuer.getID(a[1])
    issuer.setRegistrar(kyc, False, {'from': a[0]})
    issuer.getID(a[1])
    issuer.getID(a[2])
    check.reverts(issuer.getID, (a[3],), "Address not registered")


def cust_auth_id():
    '''investor / authority collisions'''
    issuer.addAuthority([a[-1]], [], 2000000000, 1, {'from': a[0]})
    id_ = issuer.getID(a[-1])
    kyc.addInvestor(id_, 1, 1, 1, 9999999999, (a[1],a[3]), {'from': a[0]})
    check.reverts(issuer.getID, (a[1],), "Address not registered")
    rpc.revert()
    kyc.addInvestor(id_, 1, 1, 1, 9999999999, (a[1],a[3]), {'from': a[0]})
    issuer.getID.transact(a[1])
    check.reverts(
        issuer.addAuthority,
        ([a[-1]], [], 2000000000, 1, {'from': a[0]}),
        "dev: known ID"
    )
