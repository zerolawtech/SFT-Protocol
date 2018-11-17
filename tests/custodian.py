#!/usr/bin/python3

import time

DEPLOYMENT = "simple"

def create_custodians():
    '''Create custodians''' 
    global issuer, token, a, cust1, cust2
    issuer = IssuingEntity[0]
    token = SecurityToken[0]
    a = accounts
    cust1 = a[10].deploy(Custodian, [a[10]], 1)
    cust2 = a[11].deploy(Custodian, [a[11]], 1)
    issuer.addCustodian(cust1)
    issuer.addCustodian(cust2)
    check.equal(issuer.getInvestorCounts()[0][0],0,"Investor count is wrong")

def transfers():
    '''Transfers from investor to custodian'''
    token.transfer(a[2],100)
    token.transfer(cust1,100,{'from':a[2]})
    check.equal(issuer.getInvestorCounts()[0][0],1,"Investor count is wrong")
    token.transfer(a[2],100)
    check.equal(issuer.getInvestorCounts()[0][0],1,"Investor count is wrong")
    cust1.transfer(token,a[2],100,True)
    check.equal(issuer.getInvestorCounts()[0][0],1,"Investor count is wrong")
    token.transfer(a[1],200,{'from':a[2]})
    check.equal(issuer.getInvestorCounts()[0][0],0,"Investor count is wrong")
    

def transfers2():
    '''Transfers with multiple custodians''' 
    token.transfer(a[2],1000)
    token.transfer(cust1,500,{'from':a[2]})
    token.transfer(cust2,500,{'from':a[2]})
    check.equal(issuer.getInvestorCounts()[0][0],1,"Investor count is wrong")
    token.transfer(a[2],1000)
    check.equal(issuer.getInvestorCounts()[0][0],1,"Investor count is wrong")
    cust1.transfer(token,a[2],500,True)
    check.equal(issuer.getInvestorCounts()[0][0],1,"Investor count is wrong")
    cust2.transfer(token,a[2],400,True)
    cust2.transfer(token,a[3],100,True)
    check.equal(issuer.getInvestorCounts()[0][0],2,"Investor count is wrong")
    token.transfer(a[1],1900,{'from':a[2]})
    check.equal(issuer.getInvestorCounts()[0][0],1,"Investor count is wrong")
    token.transfer(a[1],100,{'from':a[3]})
    check.equal(issuer.getInvestorCounts()[0][0],0,"Investor count is wrong")
    
def transfer3():
    '''Transfers between issuer and custodians'''    
    token.transfer(cust1,1000)
    check.equal(issuer.getInvestorCounts()[0][0],0,"Investor count is wrong")
    cust1.transfer(token,issuer,1000,True)
    check.equal(issuer.getInvestorCounts()[0][0],0,"Investor count is wrong")
    token.transfer(cust1,1000)
    token.transfer(cust2,1000)
    cust1.transfer(token,cust2,1000,True)
    check.equal(issuer.getInvestorCounts()[0][0],0,"Investor count is wrong")
    cust2.transfer(token,issuer,2000,True)
    check.equal(issuer.getInvestorCounts()[0][0],0,"Investor count is wrong")

def transfer4():
    '''Transfers with multiple tokens'''
    token2 = a[1].deploy(SecurityToken, issuer, "Test Token2", "TS2", 1000000)
    issuer.addToken(token2)
    token.transfer(a[2],1000)
    token2.transfer(a[2],1000)
    token.transfer(cust1,1000,{'from':a[2]})
    token2.transfer(cust1,1000,{'from':a[2]})
    check.equal(issuer.getInvestorCounts()[0][0],1,"Investor count is wrong")
    cust1.transfer(token,a[2],1000,True)
    token.transfer(issuer,1000,{'from':a[2]})
    check.equal(issuer.getInvestorCounts()[0][0],1,"Investor count is wrong")
    cust1.transfer(token2,a[2],1000,True)
    token2.transfer(issuer,1000,{'from':a[2]})
    check.equal(issuer.getInvestorCounts()[0][0],0,"Investor count is wrong")

def transfer4():
    '''Multiple tokens and multiple custodians'''
    token2 = a[1].deploy(SecurityToken, issuer, "Test Token2", "TS2", 1000000)
    issuer.addToken(token2)
    token.transfer(a[2],1000)
    token2.transfer(a[2],1000)
    token.transfer(cust1,1000,{'from':a[2]})
    token2.transfer(cust1,1000,{'from':a[2]})
    check.equal(issuer.getInvestorCounts()[0][0],1,"Investor count is wrong")
    cust1.transfer(token,a[2],1000,True)
    token.transfer(issuer,1000,{'from':a[2]})
    check.equal(issuer.getInvestorCounts()[0][0],1,"Investor count is wrong")
    cust1.transfer(token2,a[2],1000,True)
    token2.transfer(issuer,1000,{'from':a[2]})
    check.equal(issuer.getInvestorCounts()[0][0],0,"Investor count is wrong")