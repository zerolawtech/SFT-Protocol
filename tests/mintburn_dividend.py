#!/usr/bin/python3

import time

DEPLOYMENT = "simple"

def mintburn_setup(network, accounts):
    '''MintBurn: deploy and attach''' 
    global issuer, token, mint
    issuer = accounts[1].IssuingEntity
    token = accounts[1].SecurityToken
    mint = accounts[1].deploy("MintBurnModule", issuer.address)
    assert issuer.revert("attachModule", issuer.address,
                         mint.address, {'from':accounts[2]}), (
                             "Account 2 was able to attach")
    issuer.attachModule(issuer.address, mint.address)
    assert issuer.revert("attachModule", issuer.address, mint.address), (
        "Was able to attach module twice")

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
    dividend_time = int(time.time()+3)
    dividend = accounts[1].deploy("DividendModule", token.address, issuer.address,
                            dividend_time)
    assert issuer.revert("attachModule", token.address,
                         dividend.address, {'from':accounts[2]}), (
                             "Account 2 was able to attach")
    issuer.attachModule(token.address, dividend.address)

def dividend_transfer(network, accounts):
    '''Dividend: transfer tokens before claim time'''
    token.transfer(accounts[2], 100)
    token.transfer(accounts[2], 300)
    token.transfer(accounts[3], 200)
    token.transfer(accounts[4], 500)
    token.transfer(accounts[5], 100, {'from':accounts[4]})
    token.transfer(accounts[6], 900)
    token.transferFrom(accounts[6], accounts[7], 600, {'from':accounts[1]})
    assert token.circulatingSupply() == 2000, "Circulating supply is wrong"

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
    dividend.issueDividend(100, {'value':2e19})
    assert dividend.revert("issueDividend", 100, {'value':1e19}), (
        "Was able to call issueDividend twice")

def dividend_claim(network, accounts):
    '''Dividend: claim dividends'''
    blank = "0x"+("0"*40)

    assert dividend.revert("claimDividend",accounts[1]), "Issuer was able to claim"
    dividend.claimDividend(accounts[8])
    for i,final in enumerate([int(4e18), int(2e18), int(4e18), int(1e18), int(3e18), int(6e18)], start=2):
        balance = accounts[i].balance()
        dividend.claimDividend(accounts[i])
        assert accounts[i].balance() == balance+final, "Dividend payout wrong: {}".format(i)
        assert dividend.revert("claimDividend",accounts[i]), "Able to claim twice"

def dividend_close(network, accounts):
    '''Dividend: close dividends'''
    dividend.closeDividend()
    token.transfer(accounts[2], 100)