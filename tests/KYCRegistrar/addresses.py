#!/usr/bin/python3

from brownie import *
from scripts.deployment import main


def setup():
    global kyc, owner_id, auth_id
    kyc = a[0].deploy(KYCRegistrar, [a[0]], 1)
    kyc.addAuthority((a[-1],a[-2]), (1,), 1, {'from': a[0]})
    owner_id = kyc.getAuthorityID(a[0])
    auth_id = kyc.getAuthorityID(a[-1])


def owner_add_authority_addresses():
    '''add addresses to authority'''
    check.reverts(kyc.getAuthorityID, ((a[1],)))
    check.reverts(kyc.getAuthorityID, ((a[2],)))
    kyc.registerAddresses(owner_id, (a[1], a[2]), {'from':a[0]})
    check.equal(kyc.getAuthorityID(a[1]), owner_id)
    check.equal(kyc.getAuthorityID(a[2]), owner_id)


def owner_restrict_authority_addresses():
    '''restrict authority addresses'''
    kyc.registerAddresses(owner_id, (a[1], a[2]), {'from':a[0]})
    kyc.registerAddresses(auth_id, (a[3], a[4]), {'from':a[0]})
    kyc.restrictAddresses(owner_id, (a[1], a[2]), {'from':a[0]})
    kyc.restrictAddresses(auth_id, (a[3], a[4]), {'from':a[0]})
    for i in range(1,5):
        check.false(kyc.isApprovedAuthority(a[i], 1))


def owner_unrestrict_authority_address():
    '''unrestrict authority addresses'''
    kyc.registerAddresses(owner_id, (a[1], a[2]), {'from':a[0]})
    kyc.registerAddresses(auth_id, (a[3], a[4]), {'from':a[0]})
    kyc.restrictAddresses(owner_id, (a[1], a[2]), {'from':a[0]})
    kyc.restrictAddresses(auth_id, (a[3], a[4]), {'from':a[0]})
    kyc.registerAddresses(owner_id, (a[1],), {'from':a[0]})
    kyc.registerAddresses(auth_id, (a[3],), {'from':a[1]})
    check.true(kyc.isApprovedAuthority(a[1], 1))
    check.false(kyc.isApprovedAuthority(a[2], 1))
    check.true(kyc.isApprovedAuthority(a[3], 1))
    check.false(kyc.isApprovedAuthority(a[4], 1))


def add_addresses_known_address():
    '''cannot add known addresses'''
    kyc.registerAddresses(owner_id, (a[1], a[2]), {'from':a[0]})
    kyc.registerAddresses(auth_id, (a[3], a[4]), {'from':a[0]})
    kyc.addInvestor("0x123456", 1, 1, 1, 9999999999, (a[6],), {'from': a[0]})
    check.reverts(
        kyc.registerAddresses,
        (owner_id, (a[1], a[5]), {'from':a[0]}),
        "dev: known address"
    )
    check.reverts(
        kyc.registerAddresses,
        (owner_id, (a[3], a[5]), {'from':a[0]}),
        "dev: known address"
    )
    check.reverts(
        kyc.registerAddresses,
        (owner_id, (a[6],), {'from':a[0]}),
        "dev: known address"
    )
    check.reverts(
        kyc.registerAddresses,
        (owner_id, (a[6],), {'from':a[0]}),
        "dev: known address"
    )
    check.reverts(
        kyc.registerAddresses,
        (kyc.getID(a[6]), (a[3],), {'from': a[0]}),
        "dev: known address"
    )


def add_address_repeat():
    '''cannot add - repeat addresses'''
    check.reverts(
        kyc.registerAddresses,
        (owner_id, (a[1], a[2], a[1]), {'from':a[0]}),
        "dev: known address"
    )


def restrict_already_restricted():
    '''cannot restrict - already restricted'''
    kyc.registerAddresses(owner_id, (a[1], a[2]), {'from': a[0]})
    kyc.registerAddresses(auth_id, (a[3], a[4]), {'from': a[0]})
    kyc.addInvestor("0x123456", 1, 1, 1, 9999999999, (a[6],), {'from': a[0]})
    kyc.restrictAddresses(owner_id, (a[1],), {'from': a[0]})
    check.reverts(
        kyc.restrictAddresses,
        (owner_id, (a[1],), {'from': a[0]}),
        "dev: already restricted"
    )
    kyc.restrictAddresses(auth_id, (a[4],), {'from': a[0]})
    check.reverts(
        kyc.restrictAddresses,
        (auth_id, (a[4],), {'from': a[0]}),
        "dev: already restricted"
    )
    kyc.restrictAddresses("0x123456", (a[6],), {'from': a[0]})
    check.reverts(
        kyc.restrictAddresses,
        ("0x123456", (a[6],), {'from': a[0]}),
        "dev: already restricted"
    )


def restrict_wrong_ID():
    '''cannot restrict - wrong ID'''
    kyc.registerAddresses(owner_id, (a[1], a[2]), {'from': a[0]})
    kyc.registerAddresses(auth_id, (a[3], a[4]), {'from': a[0]})
    kyc.addInvestor("0x123456", 1, 1, 1, 9999999999, (a[6],), {'from': a[0]})
    check.reverts(
        kyc.restrictAddresses,
        (owner_id, (a[3],), {'from': a[0]}),
        "dev: wrong ID"
    )
    check.reverts(
        kyc.restrictAddresses,
        (owner_id, (a[6],), {'from': a[0]}),
        "dev: wrong ID"
    )
    check.reverts(
        kyc.restrictAddresses,
        ("0x123456", (a[1],), {'from': a[0]}),
        "dev: wrong ID"
    )


def remove_address_threshold():
    '''cannot restrict authority addresses - below threshold'''
    kyc.setAuthorityThreshold(auth_id, 2, {'from': a[0]})
    check.reverts(
        kyc.restrictAddresses,
        (auth_id, (a[-1],), {'from':a[0]}),
        "dev: below threshold"
    )


def authority_add_authority_addresses():
    '''authority cannot add authority addresses'''
    check.reverts(
        kyc.registerAddresses,
        (owner_id, (a[1], a[2]), {'from':a[-1]}),
        "dev: not owner"
    )
    check.reverts(
        kyc.registerAddresses,
        (auth_id, (a[1], a[2]), {'from':a[-1]}),
        "dev: not owner"
    )


def authority_restrict_authority_addresses():
    '''authority cannot restrict authority addresses'''
    kyc.registerAddresses(owner_id, (a[1], a[2]), {'from':a[0]})
    kyc.registerAddresses(auth_id, (a[3], a[4]), {'from':a[0]})
    check.reverts(
        kyc.restrictAddresses,
        (owner_id, (a[1], a[2]), {'from':a[-1]}),
        "dev: not owner"
    )
    check.reverts(
        kyc.restrictAddresses,
        (auth_id, (a[3], a[4]), {'from':a[-1]}),
        "dev: not owner"
    )


def owner_add_investor_addresses():
    '''owner - add investor addresses'''
    kyc.addInvestor("0x123456", 1, 1, 1, 9999999999, (a[1],), {'from': a[0]})
    kyc.registerAddresses("0x123456", (a[2], a[3]), {'from': a[0]})
    check.equal(kyc.getID(a[2]), "0x123456")
    check.equal(kyc.getID(a[3]), "0x123456")


def authority_add_investor_addresses():
    '''authority - add investor addresses'''
    kyc.addInvestor("0x123456", 1, 1, 1, 9999999999, (a[1],), {'from': a[-1]})
    kyc.registerAddresses("0x123456", (a[2], a[3]), {'from': a[-1]})
    check.equal(kyc.getID(a[2]), "0x123456")
    check.equal(kyc.getID(a[3]), "0x123456")


def authority_add_addresses_not_permitted_country():
    '''authority - add investor addresses - not permitted country'''
    kyc.addInvestor("0x123456", 2, 1, 1, 9999999999, (a[1],), {'from': a[0]})
    check.reverts(
        kyc.registerAddresses,
        ("0x123456", (a[2],), {'from':a[-1]}),
        "dev: country"
    )
    kyc.setAuthorityCountries(auth_id, (2,), True, {'from': a[0]})
    kyc.registerAddresses("0x123456", (a[2],), {'from':a[-1]})


def authority_restrict_addresses_not_permitted_country():
    '''authority - restrict investor addresses - not permitted country'''
    kyc.addInvestor("0x123456", 2, 1, 1, 9999999999, (a[1], a[2]), {'from': a[0]})
    check.reverts(
        kyc.restrictAddresses,
        ("0x123456", (a[1],), {'from':a[-1]}),
        "dev: country"
    )
    kyc.setAuthorityCountries(auth_id, (2,), True, {'from': a[0]})
    kyc.restrictAddresses("0x123456", (a[1],), {'from':a[-1]})
