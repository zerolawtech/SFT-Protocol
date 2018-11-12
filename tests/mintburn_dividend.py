#!/usr/bin/python3

import time

DEPLOYMENT = "simple"

def mintburn_setup():
    '''MintBurn: deploy and attach''' 
    global issuer, token, mint
    issuer = IssuingEntity[0]
    token = SecurityToken[0]
    mint = check.confirms(
        accounts[1].deploy,
        (MintBurnModule, issuer.address),
        "Could not deploy MintBurn")
    check.reverts(
        issuer.attachModule,
        (issuer.address,mint.address, {'from':accounts[2]}),
        "Account 2 was able to attach MintBurn module")
    check.confirms(
        issuer.attachModule,
        (issuer.address, mint.address),
        "Issuer could not attach MintBurn module")
    check.reverts(
        issuer.attachModule,
        (issuer.address, mint.address),
        "Issuer was able to attach module twice")

def mintburn_mint():
    '''MintBurn: mint tokens'''
    check.confirms(mint.mint, (token.address, 1000000), "Unable to mint")
    check.equal(token.balanceOf(issuer.address), 2000000, "Issuer balance is wrong")
    check.reverts(
        mint.mint,
        (token.address, 1, {'from':accounts[2]}),
        "Account 2 was able to mint")

def mintburn_transfer():
    '''MintBurn: transfer tokens while attached'''
    check.confirms(token.transfer, (accounts[2],10000), "Unable to send tokens")
    check.confirms(token.transfer,(accounts[1],10000, {'from':accounts[2]}), "Unable to send tokens")

def mintburn_burn():
    '''MintBurn: burn tokens'''
    check.confirms(mint.burn,(token.address, 1000000),"Unable to burn")
    check.equal(token.balanceOf(issuer.address), 1000000, "Issuer balance is wrong")
    check.reverts(
        mint.burn, (token.address, 1000000, {'from':accounts[2]}),
        "Account 2 was able to burn")
    check.reverts(
        mint.burn, (token.address, 2000000),
        "Was able to burn more tokens than currently exist")

def mintburn_detach():
    '''MintBurn: detach module'''
    check.reverts(
        issuer.detachModule,
        (issuer.address, mint.address, {'from':accounts[2]}),
        "Was able to detach from account 2")
    check.reverts(
        issuer.detachModule,
        (token.address, mint.address),
        "Was able to detach from token instead of issuer")
    check.confirms(
        issuer.detachModule,
        (issuer.address, mint.address),
        "Unable to detach module")

def mintburn_final():
    '''MintBurn: attach and detach once more'''
    check.confirms(
        issuer.attachModule,
        (issuer.address, mint.address),
        "Unable to attach module")
    check.confirms(
        issuer.detachModule,
        (issuer.address, mint.address),
        "Unable to attach module")

def dividend_setup():
    '''Dividend: deploy and attach'''
    global dividend_time, dividend
    dividend_time = int(time.time()+3)
    dividend = check.confirms(
        accounts[1].deploy,
        (DividendModule, token.address, issuer.address, dividend_time),
        "Should have deployed Dividend module")
    check.reverts(
        issuer.attachModule,
        (token.address, dividend.address, {'from':accounts[2]}),
        "Account 2 was able to attach")
    check.confirms(
        issuer.attachModule,
        (token.address, dividend.address),
        "Unable to attach module")

def dividend_transfer():
    '''Dividend: transfer tokens before claim time'''
    token.transfer(accounts[2], 100)
    token.transfer(accounts[2], 300)
    token.transfer(accounts[3], 200)
    token.transfer(accounts[4], 500)
    token.transfer(accounts[5], 100, {'from':accounts[4]})
    token.transfer(accounts[6], 900)
    token.transferFrom(accounts[6], accounts[7], 600, {'from':accounts[1]})
    check.equal(token.circulatingSupply(), 2000, "Circulating supply is wrong")

def dividend_mint():
    '''Dividend: attach MintBurn, mint and burn tokens'''
    issuer.attachModule(issuer.address, mint.address)
    mint.mint(token.address, 1000000)
    mint.burn(token.address, 500000)
    issuer.detachModule(issuer.address, mint.address)

def dividend_transfer2():
    '''Dividend: transfer tokens after claim time'''
    if dividend_time > time.time():
        time.sleep(dividend_time-time.time()+1)
    token.transfer(accounts[2], 100000)
    token.transfer(accounts[2], 10000)

def dividend_issue():
    '''Dividend: issue the dividend'''
    check.reverts(
        dividend.issueDividend,
        (100, {'from':accounts[2], 'value':1e19}),
        "Dividend was successfully issued by account 2")
    check.reverts(dividend.issueDividend, (100,),
        "Was able to issue a dividend without sending any eth")
    check.confirms(
        dividend.issueDividend,
        (100, {'value':2e19}),
        "Unable to issue Dividend")
    check.reverts(
        dividend.issueDividend,
        (100, {'value':1e19}),
        "Was able to call issueDividend twice")

def dividend_claim():
    '''Dividend: claim dividends'''
    blank = "0x"+("0"*40)

    check.reverts(
        dividend.claimDividend,
        (accounts[1],),
        "Issuer was able to claim")
    #dividend.claimDividend(accounts[8])
    for i,final in enumerate([int(4e18), int(2e18), int(4e18), int(1e18), int(3e18), int(6e18)], start=2):
        balance = accounts[i].balance()
        dividend.claimDividend(accounts[i])
        check.equal(accounts[i].balance(), balance+final, "Dividend payout wrong: {}".format(i))
        check.reverts(dividend.claimDividend,(accounts[i],), "Able to claim twice")

def dividend_close():
    '''Dividend: close dividends'''
    dividend.closeDividend()
    token.transfer(accounts[2], 100)