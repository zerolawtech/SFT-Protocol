from brownie import *
from scripts.deployment import main


def setup():
    config['test']['default_contract_owner'] = True
    main(NFToken)
    global token, issuer
    token = NFToken[0]
    issuer = IssuingEntity[0]


def add_tags_via_mint():
    '''Add tags through minting'''
    token.mint(a[1], 1000, 0, "0x0100")
    token.mint(a[2], 1000, 0, "0x0002")
    token.mint(a[3], 1000, 0, "0xff33")
    token.mint(a[4], 1000, 0, "0x0123")
    check.equal(
        token.getRange(1),
        (a[1], 1, 1001, 0, "0x0100", "0x00")
    )
    check.equal(
        token.getRange(1001),
        (a[2], 1001, 2001, 0, "0x0002", "0x00")
    )
    check.equal(
        token.getRange(2001),
        (a[3], 2001, 3001, 0, "0xff33", "0x00")
    )
    check.equal(
        token.getRange(3001),
        (a[4], 3001, 4001, 0, "0x0123", "0x00")
    )