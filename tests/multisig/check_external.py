#!/usr/bin/python3

from brownie import *
from scripts.deployment import main


def setup():
    config['test']['always_transact'] = False
    main(SecurityToken)
    global token, nft, issuer, ownerid, id1
    token = SecurityToken[0]
    issuer = IssuingEntity[0]
    nft = a[0].deploy(NFToken, issuer, "Test NFT", "NFT", 1000000)
    issuer.addToken(nft, {'from': a[0]})
    for i in range(6):
        a.add()
        a[0].transfer(a[-1], "1 ether")
    issuer.addAuthority(a[-6:-3],[], 2000000000, 1, {'from': a[0]})
    ownerid = issuer.ownerID()
    id1 = issuer.getID(a[-6])
    token.mint(a[2], 1000, {'from': a[0]})
    nft.mint(a[2], 1000, 0, "0x00", {'from': a[0]})

def token_modifyAuthorizedSupply():
    _multisig(token.modifyAuthorizedSupply, 10000)

def token_mint():
    _multisig(token.mint, a[2], 1000)

def token_burn():
    _multisig(token.burn, a[2], 1000)

def nft_modifyAuthorizedSupply():
    _multisig(nft.modifyAuthorizedSupply, 10000)

def nft_mint():
    _multisig(nft.mint, a[2], 1000, 0, "0x00")

def nft_burn():
    _multisig(nft.burn, 1, 500)

def nft_modifyRange():
    _multisig(nft.modifyRange, 1, 0, "0xff")

def nft_modifyRanges():
    _multisig(nft.modifyRanges, 30, 800, 0, "0xff")




def _multisig(fn, *args):
    args = list(args)+[{'from':a[-6]}]
    # check for failed call, no permission
    check.reverts(fn, args, "dev: not permitted")
    # give permission and check for successful call
    issuer.setAuthoritySignatures(id1, [fn.signature], True, {'from': a[0]})
    check.event_fired(fn(*args),'MultiSigCallApproved')
    rpc.revert()
    # give permission, threhold to 3, check for success and fails
    issuer.setAuthoritySignatures(id1, [fn.signature], True, {'from': a[0]})
    issuer.setAuthorityThreshold(id1, 3, {'from': a[0]})
    args[-1]['from'] = a[-6]
    check.event_not_fired(fn(*args), 'MultiSigCallApproved')
    check.reverts(fn, args, "dev: repeat caller")
    args[-1]['from'] = a[-5]
    check.event_not_fired(fn(*args), 'MultiSigCallApproved')
    check.reverts(fn, args, "dev: repeat caller")
    args[-1]['from'] = a[-4]
    check.event_fired(fn(*args),'MultiSigCallApproved')
    
    
