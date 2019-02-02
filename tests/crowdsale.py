#!/usr/bin/python3

from brownie import *
from scripts.deploy_simple import main

def setup():
    main()
    global issuer, token, sale
    issuer = IssuingEntity[0]
    token = SecurityToken[0]
    sale = accounts[1].deploy(
        CrowdsaleModule,
        token.address,
        issuer.address,
        accounts[9],            # receiving address
        int(rpc.time()+2),    # start time
        int(rpc.time()+30),    # end time
        100000,                 # eth fiat peg in cents
        5,                      # token fiat peg in cents
        2000000,                # fiat cap in cents
        0,                      # max tokens sold
        [],                     # bonus %s
        [])                     # bonus start times
    issuer.attachModule(token, sale)

def crowdsale_not_open():
    '''Try to send eth before it opens'''
    check.reverts(accounts[1].transfer, (sale, 1e18), "Was able to send eth")
    check.reverts(accounts[2].transfer, (sale, 1e18), "Was able to send eth")

def crowdsale_open():
    '''Send eth once sale is open'''
    rpc.sleep(3)
    accounts[2].transfer(sale.address, 1e18) # $1000
    check.equal(token.balanceOf(accounts[2]), 20000, "Token balance is wrong")
    check.equal(accounts[9].balance(), 101e18, "Receiver balance is wrong")
    accounts[3].transfer(sale.address, 5e16) # $50
    check.equal(token.balanceOf(accounts[3]), 1000, "Token balance is wrong")
    accounts[3].transfer(sale.address, 9.5e17) # $950
    check.equal(token.balanceOf(accounts[3]), 20000, "Token balance is wrong")
    check.equal(accounts[9].balance(), 102e18, "Receiver balance is wrong")
    # assert accounts[1].revert("transfer", sale.address, 1e18), "Issuer was able to participate"
    # accounts[4].transfer(sale.address, 8e18) # $8000
    # assert token.balanceOf(accounts[4]) == 160000,  "Token balance is wrong"
    # assert accounts[9].balance() == 110e18, "Receiver balance is wrong"
    # accounts[5].transfer(sale.address, 9e18) # $9000
    # assert token.balanceOf(accounts[5]) == 180000,  "Token balance is wrong"
    # assert accounts[9].balance() == 119e18, "Receiver balance is wrong"