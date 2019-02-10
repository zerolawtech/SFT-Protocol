#!/usr/bin/python3

from brownie import *
from scripts.deploy_simple import main

def setup():
    main()
    global issuer, token, a
    issuer = IssuingEntity[0]
    token = SecurityToken[0]
    a = accounts


def first_test():
    '''transfer balance''' 
    check.confirms(token.transfer, (a[2], 101), "Unable to send to account 2")
    check.equal(token.balanceOf(a[2]), 101, "Wrong balance on account 2")

def check_start_balance():
    '''check balance has been reset in the next test''' 
    check.equal(token.balanceOf(a[2]), 0, "Wrong starting balance on account 2")

# peg your installed version of ganache-cli to 6.2.5 or this will fail
def check_balance_after_transfer():
    '''check balance increases correctly after transfer''' 
    check.equal(token.balanceOf(a[2]), 0, "Wrong starting balance on account 2")
    check.confirms(token.transfer, (a[2], 400), "Unable to send to account 2")
    check.equal(token.balanceOf(a[2]), 400, "Wrong balance on account 2")
