#!/usr/bin/python3

import time

DEPLOYMENT = "simple"

def mintburn_setup(network, accounts):
    '''MintBurn: deploy and attach''' 
    global issuer, token, module
    issuer = network.IssuingEntity
    token = network.SecurityToken
    module = network.deploy("MintBurn", issuer.address, {'from':accounts[1]})
    assert issuer.revert("attachModule", issuer.address,
                         module.address, {'from':accounts[2]}), (
                             "Account 2 was able to attach")
    issuer.attachModule(issuer.address, module.address)

def mintburn_mint(network, accounts):
    '''MintBurn: mint tokens'''
    module.mint(token.address, 1000000)
    assert token.balanceOf(issuer.address) == 2000000, "Issuer balance is wrong"
    assert module.revert("mint", token.address, 1, {'from':accounts[2]}), (
        "Account 2 was able to mint")

def mintburn_transfer(network, accounts):
    '''MintBurn: transfer tokens while attached'''
    token.transfer(accounts[2],10000)
    token.transfer(accounts[1],10000, {'from':accounts[2]})

def mintburn_burn(network, accounts):
    '''MintBurn: burn tokens'''
    module.burn(token.address, 1000000)
    assert token.balanceOf(issuer.address) == 1000000, "Issuer balance is wrong"
    assert module.revert("burn", token.address, 1000000, {'from':accounts[2]}), (
        "Account 2 was able to burn")
    assert module.revert("burn", token.address, 2000000), (
        "Was able to burn more tokens than currently exist")

def mintburn_detach(network, accounts):
    '''MintBurn: detach module'''
    assert issuer.revert("detachModule", issuer.address,
                         module.address, {'from':accounts[2]}), (
                             "Was able to detach from account 2")
    assert issuer.revert("detachModule", token.address, module.address), (
        "Was able to detach from token instead of issuer"
    )
    issuer.detachModule(issuer.address, module.address)

def mintburn_final(network, accounts):
    '''MintBurn: attach and detach once more'''
    issuer.attachModule(issuer.address, module.address)
    issuer.detachModule(issuer.address, module.address)

def dividend_setup(network, accounts):
    '''Dividend: deploy and attach'''
    global dividend_time
    dividend_time = int(time.time()+10)
    module = network.deploy("DividendModule", token.address, issuer.address,
                            dividend_time, {'from':accounts[1]})
    assert issuer.revert("attachModule", token.address,
                         module.address, {'from':accounts[2]}), (
                             "Account 2 was able to attach")
    issuer.attachModule(token.address, module.address)

def dividend_transfer(network, accounts):
    '''Dividend: transfer tokens before claim time'''
    token.transfer(accounts[2], 10000)
    token.transfer(accounts[3], 20000)
    token.transfer(accounts[4], 50000)
    token.transfer(accounts[5], 10000, {'from':accounts[4]})
    token.transfer(accounts[6], 100000)
    token.transferFrom(accounts[6], accounts[7], 60000, {'from':accounts[1]})

def dividend_transfer2(network, accounts):
    '''Dividend: transfer tokens after claim time'''
    if dividend_time > time.time():
        time.sleep(dividend_time-time.time()+1)
    token.transfer(accounts[2], 100000)