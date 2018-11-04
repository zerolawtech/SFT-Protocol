#!/usr/bin/python3

DEPLOYMENT="simple"

def mintburn_setup(network, accounts):
    """MintBurn: deploy and attach""" 
    global issuer, token, module
    issuer = network.IssuingEntity
    token = network.SecurityToken
    module = network.deploy("MintBurn", issuer.address, {'from':accounts[1]})
    issuer.attachModule(issuer.address, module.address)

def mintburn_mint(network, accounts):
    """MintBurn: mint tokens"""
    module.mint(token.address, 1000000)
    assert token.balanceOf(issuer.address) == 2000000, "Issuer balance is wrong"
    try:
        module.mint(token.address, 1, {'from':accounts[2]})
        assert False, "Account 2 was able to mint"
    except ValueError:
        pass

def mintburn_burn(network, accounts):
    """MintBurn: burn tokens"""
    module.burn(token.address, 1000000)
    assert token.balanceOf(issuer.address) == 1000000, "Issuer balance is wrong"
    try:
        module.burn(token.address, 1000000, {'from':accounts[2]})
        assert False, "Account 2 was able to burn"
    except ValueError:
        pass
    try:
        module.burn(token.address, 2000000)
        assert False, "Was able to burn more tokens than currently exist"
    except ValueError:
        pass

def mintburn_detach(network, accounts):
    """MintBurn: detach module"""
    try:
        issuer.detachModule(issuer.address, module.address, {'from':accounts[2]})
        assert False, "Was able to detach from account 2"
    except ValueError:
        pass
    issuer.detachModule(issuer.address, module.address)