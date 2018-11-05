#!/usr/bin/python3

import time

DEPLOYMENT = "simple"

def mintburn_setup(network, accounts):
    '''MintBurn: deploy and attach''' 
    global issuer, token, mint
    issuer = network.IssuingEntity
    token = network.SecurityToken
    mint = network.deploy("MintBurn", issuer.address, {'from':accounts[1]})
    assert issuer.revert("attachModule", issuer.address,
                         mint.address, {'from':accounts[2]}), (
                             "Account 2 was able to attach")
    issuer.attachModule(issuer.address, mint.address)

def mintburn_mint(network, accounts):
    '''MintBurn: mint tokens'''
    mint.mint(token.address, 1000000)
    assert token.balanceOf(issuer.address) == 2000000, "Issuer balance is wrong"
    assert mint.revert("mint", token.address, 1, {'from':accounts[2]}), (
        "Account 2 was able to mint")

def mintburn_transfer(network, accounts):
    '''MintBurn: transfer tokens while attached'''
    token.transfer(accounts[2],10000)
    token.transfer(accounts[1],10000, {'from':accounts[2]})

def mintburn_burn(network, accounts):
    '''MintBurn: burn tokens'''
    mint.burn(token.address, 1000000)
    assert token.balanceOf(issuer.address) == 1000000, "Issuer balance is wrong"
    assert mint.revert("burn", token.address, 1000000, {'from':accounts[2]}), (
        "Account 2 was able to burn")
    assert mint.revert("burn", token.address, 2000000), (
        "Was able to burn more tokens than currently exist")

def mintburn_detach(network, accounts):
    '''MintBurn: detach module'''
    assert issuer.revert("detachModule", issuer.address,
                         mint.address, {'from':accounts[2]}), (
                             "Was able to detach from account 2")
    assert issuer.revert("detachModule", token.address, mint.address), (
        "Was able to detach from token instead of issuer"
    )
    issuer.detachModule(issuer.address, mint.address)

def mintburn_final(network, accounts):
    '''MintBurn: attach and detach once more'''
    issuer.attachModule(issuer.address, mint.address)
    issuer.detachModule(issuer.address, mint.address)

def dividend_setup(network, accounts):
    '''Dividend: deploy and attach'''
    global dividend_time, dividend
    dividend_time = int(time.time()+5)
    dividend = network.deploy("DividendModule", token.address, issuer.address,
                            dividend_time, {'from':accounts[1]})
    assert issuer.revert("attachModule", token.address,
                         dividend.address, {'from':accounts[2]}), (
                             "Account 2 was able to attach")
    issuer.attachModule(token.address, dividend.address)

def dividend_transfer(network, accounts):
    '''Dividend: transfer tokens before claim time'''
    token.transfer(accounts[2], 10000)
    token.transfer(accounts[2], 30000)
    token.transfer(accounts[3], 20000)
    token.transfer(accounts[4], 50000)
    token.transfer(accounts[5], 10000, {'from':accounts[4]})
    token.transfer(accounts[6], 100000)
    token.transferFrom(accounts[6], accounts[7], 60000, {'from':accounts[1]})
    assert token.balanceOf(accounts[6]) == 40000, "Account balance is wrong"

def dividend_mint(network, accounts):
    '''Dividend: attach MintBurn, mint and burn tokens'''
    issuer.attachModule(issuer.address, mint.address)
    mint.mint(token.address, 1000000)
    mint.burn(token.address, 500000)
    issuer.detachModule(issuer.address, mint.address)

def dividend_transfer2(network, accounts):
    '''Dividend: transfer tokens after claim time'''
    if dividend_time > time.time():
        time.sleep(dividend_time-time.time()+1)
    token.transfer(accounts[2], 100000)
    token.transfer(accounts[2], 10000)

def dividend_issue(network, accounts):
    '''Dividend: issue the dividend'''
    assert dividend.revert("issueDividend", 100,
                           {'from':accounts[2], 'value':1e19}), (
                               "Dividend was successfully issued by account 2")
    assert dividend.revert("issueDividend", 100), (
        "Was able to issue a dividend without sending any eth")
    dividend.issueDividend(100, {'value':1e19})
    assert dividend.revert("issueDividend", 100, {'value':1e19}), (
        "Was able to call issueDividend twice")

def dividend_claim(network, accounts):
    '''Dividend: claim dividends'''
    blank = "0x"+("0"*40)
    dividend.claimDividend(blank, {'from':accounts[2]})
    dividend.claimDividend(blank, {'from':accounts[3]})
    dividend.claimDividend(accounts[4],{'from':accounts[0]})
    dividend.claimDividend(accounts[5])
    dividend.claimMany(accounts[6:8])
    assert dividend.revert("claimDividend",blank,{'from':accounts[2]}), (
        "Dividend claimed twice by account 2")
    assert dividend.revert("claimDividend",blank), (
        "Dividend claimed by issuer")
    assert dividend.revert("claimDividend",accounts[3]), (
        "Dividend claimed twice for account 3 by issuer")

    # need to verify dividend amounts