#!/usr/bin/python3

import time

DEPLOYMENT = "simple"

def custdians():
    '''Custodians''' 
    global issuer, token, a
    issuer = IssuingEntity[0]
    token = SecurityToken[0]
    a = accounts
    cust1 = a[10].deploy(Custodian, [a[10]], 1)
    cust2 = a[11].deploy(Custodian, [a[11]], 1)
    issuer.addCustodian(cust1)
    issuer.addCustodian(cust2)
    token.transfer(a[2],100)
    check.equal(issuer.getInvestorCounts()[0][0],1,"Investor count is wrong")
    token.transfer(cust1,100,{'from':a[2]})
    check.equal(issuer.getInvestorCounts()[0][0],1,"Investor count is wrong")
    token.transfer(a[2],100)
    check.equal(issuer.getInvestorCounts()[0][0],1,"Investor count is wrong")
    check.confirms(cust1.transfer,(token,a[2],100,True))
    check.equal(issuer.getInvestorCounts()[0][0],1,"Investor count is wrong")
    token.transfer(a[1],200,{'from':a[2]})
    check.equal(issuer.getInvestorCounts()[0][0],0,"Investor count is wrong")
    token.transfer(a[2],1000)
    token.transfer(cust1,500,{'from':a[2]})
    token.transfer(cust2,500,{'from':a[2]})
    check.equal(issuer.getInvestorCounts()[0][0],1,"Investor count is wrong")
    token.transfer(a[2],1000)
    check.equal(issuer.getInvestorCounts()[0][0],1,"Investor count is wrong")
    check.confirms(cust1.transfer,(token,a[2],500,True))
    check.equal(issuer.getInvestorCounts()[0][0],1,"Investor count is wrong")
    check.confirms(cust2.transfer,(token,a[2],400,True))
    check.confirms(cust2.transfer,(token,a[3],100,True))
    check.equal(issuer.getInvestorCounts()[0][0],2,"Investor count is wrong")
    token.transfer(a[1],1900,{'from':a[2]})
    check.equal(issuer.getInvestorCounts()[0][0],1,"Investor count is wrong")
    token.transfer(a[1],100,{'from':a[3]})
    check.equal(issuer.getInvestorCounts()[0][0],0,"Investor count is wrong")
    token.transfer(cust1,1000)
    check.equal(issuer.getInvestorCounts()[0][0],0,"Investor count is wrong")