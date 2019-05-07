#!/usr/bin/python3

from brownie import *
from scripts.deployment import main


def setup():
    main(SecurityToken)
    global token, issuer, ownerid, id1, id2
    token = SecurityToken[0]
    issuer = IssuingEntity[0]
    for i in range(10):
        a.add()
    sigs = (
        issuer.signatures['addAuthorityAddresses'],
        issuer.signatures['removeAuthorityAddresses'],
    )
    issuer.addAuthority([a[-2]], sigs, 2000000000, 1, {'from': a[0]})
    issuer.addAuthority([a[-1]], sigs, 2000000000, 1, {'from': a[0]})
    a[0].transfer(a[-2], "1 ether")
    a[0].transfer(a[-1], "1 ether")
    ownerid = issuer.ownerID()
    id1 = issuer.getID(a[-2])
    id2 = issuer.getID(a[-1])

def add_addr_owner():
    '''add addresses to owner'''
    issuer.addAuthorityAddresses(ownerid, a[-6:-4], {'from': a[0]})
    check.equal(issuer.getAuthority(ownerid), (3, 1, 0))
    issuer.addAuthorityAddresses(ownerid, (a[-4],), {'from': a[0]})
    check.equal(issuer.getAuthority(ownerid), (4, 1, 0))

def remove_addr_owner():
    '''remove addresses from owner'''
    issuer.addAuthorityAddresses(ownerid, a[-10:-5], {'from': a[0]})
    issuer.removeAuthorityAddresses(ownerid, a[-10:-6], {'from': a[0]})
    check.equal(issuer.getAuthority(ownerid), (2, 1, 0))

def add_remove_owner():
    '''add and remove - owner'''
    issuer.addAuthorityAddresses(ownerid, a[-10:-5], {'from': a[0]})
    issuer.removeAuthorityAddresses(ownerid, a[-10:-6], {'from': a[0]})
    issuer.addAuthorityAddresses(ownerid, (a[-10], a[-9], a[-4]), {'from': a[0]})
    check.equal(issuer.getAuthority(ownerid), (5, 1, 0))

def add_addr_auth():
    '''add addresses to authorities'''
    issuer.addAuthorityAddresses(id1, a[-10:-7], {'from': a[0]})
    check.equal(issuer.getAuthority(id1), (4, 1, 2000000000))
    issuer.addAuthorityAddresses(id1, (a[-7],), {'from': a[0]})
    check.equal(issuer.getAuthority(id1), (5, 1, 2000000000))
    issuer.addAuthorityAddresses(id2, a[-4:-2], {'from': a[0]})
    check.equal(issuer.getAuthority(id2), (3, 1, 2000000000))

def remove_addr_auth():
    '''remove addresses from authorities'''
    issuer.addAuthorityAddresses(id1, a[-10:-7], {'from': a[0]})
    issuer.addAuthorityAddresses(id2, a[-4:-2], {'from': a[0]})
    issuer.removeAuthorityAddresses(id1, a[-10:-8], {'from': a[0]})
    issuer.removeAuthorityAddresses(id2, a[-4:-2], {'from': a[0]})
    check.equal(issuer.getAuthority(id1), (2, 1, 2000000000))
    check.equal(issuer.getAuthority(id2), (1, 1, 2000000000))

def add_remove_auth():
    '''add and remove - authorities'''
    issuer.addAuthorityAddresses(id1, a[-10:-7], {'from': a[0]})
    issuer.addAuthorityAddresses(id2, a[-7:-5], {'from': a[0]})
    issuer.removeAuthorityAddresses(id1, a[-10:-8], {'from': a[0]})
    issuer.removeAuthorityAddresses(id2, [a[-7]], {'from': a[0]})
    issuer.addAuthorityAddresses(id1, (a[-10], a[-9], a[-5]), {'from': a[0]})
    issuer.addAuthorityAddresses(id2, (a[-7], a[-4]), {'from': a[0]})
    check.equal(issuer.getAuthority(id1), (5, 1, 2000000000))
    check.equal(issuer.getAuthority(id2), (4, 1, 2000000000))

def add_known():
    '''add known addresses'''
    issuer.addAuthorityAddresses(id1, a[-10:-7], {'from': a[0]})
    check.reverts(
        issuer.addAuthorityAddresses,
        (id1, a[-9:-6], {'from': a[0]}),
        "dev: known address"
    )
    check.reverts(
        issuer.addAuthorityAddresses,
        (id1, (a[-6], a[-5], a[-6]), {'from': a[0]}),
        "dev: known address"
    )

def add_other():
    '''add already assocaited address'''
    token.mint(a[1], 100, {'from': a[0]})
    issuer.addAuthorityAddresses(id1, (a[-10],), {'from': a[0]})
    check.reverts(
        issuer.addAuthorityAddresses,
        (id1, (a[-10],), {'from': a[0]}),
        "dev: known address"
    )
    check.reverts(
        issuer.addAuthorityAddresses,
        (id1, (a[1],), {'from': a[0]}),
        "dev: known address"
    )


def remove_below_threshold():
    '''remove below threshold'''
    issuer.addAuthorityAddresses(id1, a[-10:-7], {'from': a[0]})
    issuer.setAuthorityThreshold(id1, 3, {'from': a[0]})
    check.reverts(
        issuer.removeAuthorityAddresses,
        (id1, a[-10:-7], {'from': a[0]}),
        "dev: count below threshold"
    )
    issuer.removeAuthorityAddresses(id1, (a[-10],), {'from': a[0]})
    check.reverts(
        issuer.removeAuthorityAddresses,
        (id1, a[-9:-7], {'from': a[0]}),
        "dev: count below threshold"
    )
    check.reverts(
        issuer.removeAuthorityAddresses,
        (id2, (a[-1],), {'from': a[0]}),
        "dev: count below threshold"
    )

def remove_unknown_addresses():
    '''remove unknown addresses'''
    issuer.addAuthorityAddresses(id1, a[-10:-8], {'from': a[0]})
    check.reverts(
        issuer.removeAuthorityAddresses,
        (id1, a[-10:-6], {'from': a[0]}),
        "dev: wrong ID"
    )

def remove_repeat():
    '''remove already restricted address'''
    issuer.addAuthorityAddresses(id1, a[-10:-8], {'from': a[0]})
    check.reverts(
        issuer.removeAuthorityAddresses,
        (id1, (a[-10], a[-9], a[-10]), {'from': a[0]}),
        "dev: already restricted"
    )

def add_unknown_id():
    '''add to unknown id'''
    check.reverts(
        issuer.addAuthorityAddresses,
        ("0x1234", a[-10:-8], {'from': a[0]}),
        "dev: unknown ID"
    )

def remove_unknown_id():
    '''remove from unknown id'''
    check.reverts(
        issuer.removeAuthorityAddresses,
        ("0x1234", (a[-10],), {'from': a[0]}),
        "dev: wrong ID"
    )

def authority_add_to_self():
    '''authority - add to self'''
    issuer.addAuthorityAddresses(id1, a[-10:-8], {'from': a[-2]})
    issuer.addAuthorityAddresses(id2, a[-8:-6], {'from': a[-1]})

def authority_remove_self():
    '''authority - remove from self'''
    issuer.addAuthorityAddresses(id1, a[-10:-8], {'from': a[-2]})
    issuer.addAuthorityAddresses(id2, a[-8:-6], {'from': a[-1]})
    issuer.removeAuthorityAddresses(id1, a[-10:-8], {'from': a[-2]})
    issuer.removeAuthorityAddresses(id2, (a[-8],a[-1]), {'from': a[-1]})

def authority_add_to_other():
    '''authority - add to other'''
    check.reverts(
        issuer.addAuthorityAddresses,
        (id1, a[-10:-8], {'from': a[-1]}),
        "dev: wrong authority"
    )

def authority_remove_from_other():
    '''authority - remove from other'''
    issuer.addAuthorityAddresses(id1, a[-10:-8], {'from': a[-2]})
    check.reverts(
        issuer.removeAuthorityAddresses,
        (id1, a[-10:-8], {'from': a[-1]}),
        "dev: wrong authority"
    )