#!/usr/bin/python3

import time

DEPLOYMENT = "simple"

def crowdsale_setup(network, accounts):
    '''Deploy and attach''' 
    global issuer, token, sale
    issuer = accounts[1].IssuingEntity
    token = accounts[1].SecurityToken
    sale = accounts[1].deploy(
        "CrowdsaleModule",
        token.address,
        issuer.address,
        accounts[9],            # receiving address
        int(time.time()+2),    # start time
        int(time.time()+30),    # end time
        100000,                 # eth fiat peg in cents
        5,                      # token fiat peg in cents
        2000000,                # fiat cap in cents
        0,                      # max tokens sold
        [],                     # bonus %s
        [])                     # bonus start times
    issuer.attachModule(token.address, sale.address)

def crowdsale_not_open(network, accounts):
    '''Try to send eth before it opens'''
    assert accounts[1].revert("transfer", sale.address, 1e18), "Was able to send eth"
    assert accounts[2].revert("transfer", sale.address, 1e18), "Was able to send eth"

def crowdsale_open(network, accounts):
    time.sleep(2)
    '''Send eth once sale is open'''
    accounts[2].transfer(sale.address, 1e18) # $1000
    assert token.balanceOf(accounts[2]) == 20000, "Token balance is wrong"
    assert accounts[9].balance() == 101e18, "Receiver balance is wrong"
    accounts[3].transfer(sale.address, 5e16) # $50
    assert token.balanceOf(accounts[3]) == 1000, "Token balance is wrong"
    #assert accounts[9].balance() == 101e18, "Receiver balance is wrong"
    accounts[3].transfer(sale.address, 9.5e17) # $950
    assert token.balanceOf(accounts[3]) == 20000, "Token balance is wrong"
    assert accounts[9].balance() == 102e18, "Receiver balance is wrong"