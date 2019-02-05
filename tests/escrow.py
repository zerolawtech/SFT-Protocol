#!/usr/bin/python3

from brownie import *
from scripts.deploy_simple import main

def setup():
    main()
    global issuer, token, escrow, a, id2
    issuer = IssuingEntity[0]
    token = SecurityToken[0]
    a = accounts
    id2 = issuer.getID(a[2])
    escrow = a[0].deploy(EscrowCustodian)
    issuer.addCustodian(escrow)

def simple_execution():
    '''Execute a simple loan'''
    token.transfer(a[2],200),
    token.transfer(a[4],200)
    escrow.offerLoan(id2, token, [int(time.time()+30)],[1100],[100], {'from':a[3], 'value':1000})
    check.reverts(escrow.claimOffer, (0, {'from':a[2]}))
    token.approve(escrow, 100, {'from':a[4]})
    check.reverts(escrow.claimOffer, (0, {'from':a[4]}))
    token.approve(escrow, 100000, {'from':a[2]})
    escrow.claimOffer(0, {'from':a[2]})
    check.equal(token.balanceOf(escrow), 100)
    check.equal(escrow.balanceOf(token, id2), 100)
    check.reverts(escrow.claimCollateral, (0, {'from':a[3]}))
    escrow.makePayment(0,{'from':a[2],'value':1100})
    check.reverts(escrow.revokeOffer, (0, {'from':a[3]}))
    check.reverts(escrow.makePayment, (0,{'from':a[2],'value':1100}))
    check.equal(token.balanceOf(a[2]), 200)
    check.equal(escrow.balanceOf(token, id2), 0)

def revoke_offer():
    '''Make and revoke offers'''
    escrow.offerLoan(id2, token, [int(time.time()+30)],[1100],[100], {'from':a[3], 'value':1000})
    escrow.offerLoan(id2, token, [int(time.time()+30)],[1100],[100], {'from':a[3], 'value':1000})
    check.reverts(escrow.makePayment, (1, {'from':a[2], 'value':1100}))
    check.reverts(escrow.revokeOffer, (2, {'from':a[2]}))
    escrow.revokeOffer(2, {'from':a[3]})
    escrow.revokeOffer(1, {'from':a[3]})
    check.reverts(escrow.revokeOffer, (1, {'from':a[3]}))
    check.reverts(escrow.claimOffer, (1, {'from':a[2]}))

def multidate():
    '''Execute a more complex loan'''
    escrow.offerLoan(
        id2,
        token,
        [int(time.time()+30), int(time.time()+31)],
        [500,1100],
        [50,100],
        {'from':a[3], 'value':1000}
    )
    escrow.claimOffer(3, {'from':a[2]})
    escrow.makePayment(3,{'from':a[2],'value':200})
    check.equal(token.balanceOf(a[2]), 100)
    check.equal(escrow.balanceOf(token, id2), 100)
    escrow.makePayment(3,{'from':a[2],'value':300})
    check.equal(token.balanceOf(a[2]), 150)
    check.equal(escrow.balanceOf(token, id2), 50)
    check.reverts(escrow.revokeOffer, (3, {'from':a[3]}))
    check.reverts(escrow.claimOffer, (3, {'from':a[2]}))
    escrow.makePayment(3,{'from':a[2],'value':599})
    check.equal(token.balanceOf(a[2]), 150)
    check.equal(escrow.balanceOf(token, id2), 50)
    escrow.makePayment(3,{'from':a[2],'value':1})
    check.equal(token.balanceOf(a[2]), 200)
    check.equal(escrow.balanceOf(token, id2), 0)

def reclaim():
    '''Reposess assets in an overdue loan'''
    escrow.offerLoan(id2, token, [int(time.time()+1.5)],[1100],[100], {'from':a[3], 'value':1000})
    escrow.claimOffer(4, {'from':a[2]})
    escrow.makePayment(4, {'from':a[2],'value':200})
    time.sleep(3)
    escrow.claimCollateral(4, {'from':a[3]})
    check.equal(token.balanceOf(a[2]), 100)
    check.equal(token.balanceOf(a[3]), 100)
    check.reverts(escrow.claimCollateral, (4, {'from':a[3]}))

def pay_overdue():
    '''Pay an overdue loan'''
    escrow.offerLoan(id2, token, [int(time.time()+1.5)],[1100],[100], {'from':a[3], 'value':1000})
    escrow.claimOffer(5, {'from':a[2]})
    time.sleep(3)
    escrow.makePayment(5, {'from':a[2],'value':1100})
    check.equal(token.balanceOf(a[2]), 100)
    check.reverts(escrow.claimCollateral, (5, {'from':a[3]}))
    

def reclaim_complex():
    '''Reposess a more complex loan'''
    escrow.offerLoan(
        id2,
        token,
        [int(time.time()+1.5), int(time.time()+4.5)],
        [500,1100],
        [50,100],
        {'from':a[3], 'value':1000}
    )
    escrow.claimOffer(6, {'from':a[2]})
    escrow.makePayment(6, {'from':a[2],'value':550})
    time.sleep(3)
    check.reverts(escrow.claimCollateral,(6, {'from':a[3]}))
    time.sleep(3)
    escrow.claimCollateral(6, {'from':a[3]})
    check.equal(token.balanceOf(a[2]), 50)
    check.equal(token.balanceOf(a[3]), 150)
    check.reverts(escrow.claimCollateral, (4, {'from':a[3]}))
    check.reverts(escrow.makePayment,(4, {'from':a[2],'value':500}))

def transfer_offer():
    '''Transfer loan ownership'''
    token.transfer(a[2],150,{'from':a[3]})
    escrow.offerLoan(id2, token, [int(time.time()+30)],[1100],[100], {'from':a[3], 'value':1000})
    escrow.claimOffer(7, {'from':a[2]})
    escrow.makeTransferOffer(7, a[5], 1000, {'from':a[3]})
    b = a[3].balance()
    escrow.claimTransferOffer(7, {'from':a[5], 'value':1000})
    check.equal(b+1000,a[3].balance())
    b = a[5].balance()
    escrow.makePayment(7, {'from':a[2],'value':1100})
    check.equal(b+1100, a[5].balance())
    