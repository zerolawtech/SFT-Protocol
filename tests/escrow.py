#!/usr/bin/python3

import time

DEPLOYMENT = "simple"

def deploy_and_attach():
    '''Deploy and attach escrow custodian''' 
    global issuer, token, escrow, a, id2
    issuer = IssuingEntity[0]
    token = SecurityToken[0]
    a = accounts
    id2 = issuer.getID(a[2])
    escrow = a[0].deploy(Escrow)
    issuer.addCustodian(escrow)

def make_offer():
    '''Execute a simple loan'''
    escrow.offerLoan(id2, token, [int(time.time()+30)],[1100],[100], {'from':a[3], 'value':1000})
    token.transfer(a[2],100)
    token.approve(escrow, 100, {'from':a[2]})
    escrow.claimOffer(0, {'from':a[2]})
    check.equal(token.balanceOf(escrow), 100)
    check.equal(escrow.balanceOf(token, id2), 100)
    escrow.makePayment(0,{'from':a[2],'value':1100})
    check.equal(token.balanceOf(a[2]), 100)
    check.equal(escrow.balanceOf(token, id2), 0)