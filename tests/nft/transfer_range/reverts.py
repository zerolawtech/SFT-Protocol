from brownie import *
from scripts.deployment import main


def setup():
    config['test']['always_transact'] = False
    main(NFToken)
    global token, issuer, upper
    token = NFToken[0]
    issuer = IssuingEntity[0]
    token.mint(a[1], 10000, 0, "0x00", {'from': a[0]})
    token.mint(a[2], 10000, 0, "0x00", {'from': a[0]})
    token.mint(a[3], 10000, 0, "0x00", {'from': a[0]})
    upper = token.totalSupply()+1


def check_bounds():
    '''check bounds'''
    check.reverts(
        token.transferRange,
        (a[2], 0, 1000, {'from': a[0]}),
        "Invalid index"
    )
    check.reverts(
        token.transferRange,
        (a[2], 1000000, 1000, {'from': a[0]}),
        "Invalid index"
    )
    check.reverts(
        token.transferRange,
        (a[2], 1, 0, {'from': a[0]}),
        "Invalid index"
    )
    check.reverts(
        token.transferRange,
        (a[2], 1, 1000000, {'from': a[0]}),
        "Invalid index"
    )

def stop_start():
    '''stop below start'''
    check.reverts(
        token.transferRange,
        (a[2], 2000, 1000, {'from': a[1]}),
        "dev: stop < start"
    )

# TODO send out of custodian


def multiple_ranges():
    '''multiple ranges'''
    check.reverts(
        token.transferRange,
        (a[2], 1000, 15000, {'from': a[1]}),
        "dev: multiple ranges"
    )
    check.reverts(
        token.transferRange,
        (a[2], 10000, 10002, {'from': a[1]}),
        "dev: multiple ranges"
    )

def time_lock():
    '''time lock'''
    token.modifyRange(10001, 2000000000, "0x00", {'from': a[0]})
    check.reverts(
        token.transferRange,
        (a[1], 11000, 12000, {'from': a[2]}),
        "dev: time"
    )

# TODO prevent send from custodian?


def not_owner():
    '''sender does not own range'''
    check.reverts(
        token.transferRange,
        (a[3], 11000, 12000, {'from': a[1]}),
        "Sender does not own range"
    )

def same_addr():
    '''cannot send to self'''
    check.reverts(
        token.transferRange,
        (a[2], 11000, 12000, {'from': a[2]}),
        "Cannot send to self"
    )

# TODO issuer send / receive ?
