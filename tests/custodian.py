#!/usr/bin/python3

import time

DEPLOYMENT = "simple"

def create_custodians():
    '''Create custodians''' 
    global issuer, token, a, cust1, cust2, id2, id3, id4
    issuer = IssuingEntity[0]
    token = SecurityToken[0]
    a = accounts
    cust1 = a[10].deploy(Custodian, [a[10]], 1)
    cust2 = a[11].deploy(Custodian, [a[11]], 1)
    id2 = issuer.getID(a[2])
    id3 = issuer.getID(a[3])
    id4 = issuer.getID(a[4])
    issuer.addCustodian(cust1)
    issuer.addCustodian(cust2)
    check.equal(issuer.getInvestorCounts()[0][0],0,"Investor count is wrong")

def transfers():
    '''Transfers to and from custodian and internal transfers'''
    token.transfer(a[2],100)
    token.transfer(cust1,100,{'from':a[2]})
    check.equal(issuer.getInvestorCounts()[0][0],1,"Investor count is wrong")
    token.transfer(a[2],100)
    check.equal(issuer.getInvestorCounts()[0][0],1,"Investor count is wrong")
    check.equal(cust1.balanceOf(id2,token),100,"Custodian balance is wrong")
    token.transfer(a[3],100)
    cust1.transferInternal(token, id2, id3, 50, False)
    check.equal(cust1.balanceOf(id2,token),50,"Custodian balance is wrong")
    check.equal(cust1.balanceOf(id3,token),50,"Custodian balance is wrong")
    check.true(cust1.isBeneficialOwner(id2,issuer),"Custodian beneficial owner is wrong")
    check.true(cust1.isBeneficialOwner(id3,issuer),"Custodian beneficial owner is wrong")
    check.equal(issuer.getInvestorCounts()[0][0],2,"Investor count is wrong")
    cust1.transfer(token,a[3],50,False)
    check.false(cust1.isBeneficialOwner(id3,issuer),"Custodian beneficial owner is wrong")
    check.equal(issuer.getInvestorCounts()[0][0],2,"Investor count is wrong")
    cust1.transfer(token,a[2],50,False)
    token.transfer(a[1],150,{'from':a[2]})
    check.equal(issuer.getInvestorCounts()[0][0],1,"Investor count is wrong")
    token.transfer(a[1],150,{'from':a[3]})
    check.equal(issuer.getInvestorCounts()[0][0],0,"Investor count is wrong")


def transfers2():
    '''Set beneficial owners'''
    token.transfer(a[2],100)
    token.transfer(cust1,100,{'from':a[2]})
    cust1.transferInternal(token, id2, id3, 100, False)
    check.equal(issuer.getInvestorCounts()[0][0],1,"Investor count is wrong")
    cust1.transfer(token,a[3],100,True)
    check.equal(issuer.getInvestorCounts()[0][0],1,"Investor count is wrong")
    token.transfer(a[1],100,{'from':a[3]})
    check.equal(issuer.getInvestorCounts()[0][0],1,"Investor count is wrong")
    cust1.releaseOwnership(issuer,id3)
    check.equal(issuer.getInvestorCounts()[0][0],0,"Investor count is wrong")
    token.transfer(a[2],100)
    token.transfer(cust1,50,{'from':a[2]})
    check.equal(issuer.getInvestorCounts()[0][0],1,"Investor count is wrong")
    cust1.transfer(token,a[2],25,False)
    check.equal(issuer.getInvestorCounts()[0][0],1,"Investor count is wrong")
    cust1.transfer(token,a[2],25,False)
    token.transfer(a[1],100,{'from':a[2]})
    check.equal(issuer.getInvestorCounts()[0][0],0,"Investor count is wrong")
    

def transfers3():
    '''Internal transfers to unknown investors'''
    token.transfer(a[2],100)
    check.equal(issuer.getInvestorCounts()[0][0],1,"Investor count is wrong")
    token.transfer(cust1,100,{'from':a[2]})
    check.equal(issuer.getInvestorCounts()[0][0],1,"Investor count is wrong")
    check.reverts(cust1.transferInternal,[token,id2,"0x000012233423",100,False],"Transfer to unknown investor did not fail")
    check.reverts(cust1.transferInternal,[token,id2,id4,200,False],"Transfer should have failed")
    cust1.transferInternal(token, id2, id4, 100, False)
    check.false(cust1.isBeneficialOwner(id2,issuer),"Custodian beneficial owner is wrong")
    check.true(cust1.isBeneficialOwner(id4,issuer),"Custodian beneficial owner is wrong")
    check.equal(cust1.balanceOf(id4,token),100,"Custodian balance is wrong")
    check.equal(cust1.balanceOf(id2,token),0,"Custodian balance is wrong")
    check.equal(issuer.getInvestorCounts()[0][0],1,"Investor count is wrong")
    cust1.transferInternal(token, id4, issuer.getID(a[1]), 100, False)
    check.equal(issuer.getInvestorCounts()[0][0],0,"Investor count is wrong")
    cust1.transfer(token, a[1], 100, False)
    check.equal(issuer.getInvestorCounts()[0][0],0,"Investor count is wrong")


def transfers4():
    '''Transfers with multiple custodians'''
    token.transfer(a[2],1000)
    token.transfer(cust1,500,{'from':a[2]})
    token.transfer(cust2,500,{'from':a[2]})
    check.equal(issuer.getInvestorCounts()[0][0],1,"Investor count is wrong")
    token.transfer(a[2],1000)
    check.equal(issuer.getInvestorCounts()[0][0],1,"Investor count is wrong")
    check.reverts(cust1.transferInternal,[token,id2,cust2.ownerID(),100,False], "Custodian was able to transfer ownership to other custodian")
    cust1.transfer(token,a[2],500,False)
    check.equal(issuer.getInvestorCounts()[0][0],1,"Investor count is wrong")
    cust2.transfer(token,a[2],400,False)
    check.equal(issuer.getInvestorCounts()[0][0],1,"Investor count is wrong")
    cust2.transferInternal(token,id2,id3,100,False)
    check.equal(cust2.balanceOf(id3,token),100,"Custodian balance is wrong")
    check.equal(issuer.getInvestorCounts()[0][0],2,"Investor count is wrong")
    cust2.transfer(token,a[3],100,False)
    check.equal(issuer.getInvestorCounts()[0][0],2,"Investor count is wrong")
    token.transfer(a[1],1900,{'from':a[2]})
    check.equal(issuer.getInvestorCounts()[0][0],1,"Investor count is wrong")
    token.transfer(a[1],100,{'from':a[3]})
    check.equal(issuer.getInvestorCounts()[0][0],0,"Investor count is wrong")
    
def transfers5():
    '''Transfers between issuer and custodians'''    
    token.transfer(cust1,1000)
    check.equal(issuer.getInvestorCounts()[0][0],0,"Investor count is wrong")
    cust1.transfer(token,issuer,1000,False)
    check.equal(issuer.getInvestorCounts()[0][0],0,"Investor count is wrong")
    token.transfer(cust1,1000)
    token.transfer(cust2,1000)
    cust2.transferInternal(token,issuer.ownerID(),id3,1000,True)
    cust1.transfer(token,issuer,1000,False)
    check.equal(issuer.getInvestorCounts()[0][0],1,"Investor count is wrong")
    cust2.transferInternal(token,id3,issuer.ownerID(),1000,False)
    check.equal(issuer.getInvestorCounts()[0][0],0,"Investor count is wrong")
    cust2.transfer(token,issuer,1000,False)
    check.equal(issuer.getInvestorCounts()[0][0],0,"Investor count is wrong")

def transfers6():
    '''Transfers with multiple tokens'''
    global token2
    token2 = a[1].deploy(SecurityToken, issuer, "Test Token2", "TS2", 1000000)
    issuer.addToken(token2)
    token.transfer(a[2],1000)
    token2.transfer(a[2],1000)
    token.transfer(cust1,1000,{'from':a[2]})
    token2.transfer(cust1,1000,{'from':a[2]})
    check.equal(issuer.getInvestorCounts()[0][0],1,"Investor count is wrong")
    cust1.transfer(token,a[2],1000,False)
    token.transfer(issuer,1000,{'from':a[2]})
    check.equal(issuer.getInvestorCounts()[0][0],1,"Investor count is wrong")
    cust1.transfer(token2,a[2],1000,False)
    token2.transfer(issuer,1000,{'from':a[2]})
    check.equal(issuer.getInvestorCounts()[0][0],0,"Investor count is wrong")

def transfers7():
    '''Investor limits'''
    issuer.setInvestorLimits([1,0,0,0,0,0,0,0])
    token.transfer(a[2],1000)
    check.reverts(token.transfer,[a[3],500,{'from':a[2]}], "Exceeded investor limit")
    token.transfer(a[3],1000,{'from':a[2]})
    check.reverts(token.transfer,[a[2],1000], "Exceeded investor limit")
    token.transfer(cust1,1000,{'from':a[3]})
    check.reverts(cust1.checkTransferInternal,[token,id3,id2,500,False],"Exceeded investor limit")
    check.reverts(cust1.checkTransferInternal,[token,id3,id2,1000,True],"Exceeded investor limit")
    check.reverts(cust1.transferInternal,[token,id3,id2,500,False],"Exceeded investor limit")
    check.reverts(cust1.transferInternal,[token,id3,id2,1000,True],"Exceeded investor limit")
    cust1.checkTransferInternal(token,id3,id2,1000,False)
    cust1.transferInternal(token,id3,id2,1000,False)
    cust1.transfer(token,a[2],500,False)
    token.transfer(cust2,250,{'from':a[2]})
