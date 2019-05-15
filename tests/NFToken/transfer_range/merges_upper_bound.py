from brownie import *
from scripts.deployment import main


def setup(always_transact=False):
    main(NFToken)
    global token, issuer, upper
    token = NFToken[0]
    issuer = IssuingEntity[0]
    token.modifyAuthorizedSupply(2**48, {'from': a[0]})
    token.mint(a[1], 2**48-20002, 0, "0x00", {'from': a[0]})
    token.mint(a[2], 10000, 0, "0x00", {'from': a[0]})
    token.mint(a[3], 10000, 0, "0x00", {'from': a[0]})
    upper = token.totalSupply()+1
    _check(
        [(1, 2**48-20001)],
        [(2**48-20001, 2**48-10001)],
        [(2**48-10001, 2**48-1)],
        []
    )


def whole_range_right_abs():
    '''whole range, merge right, absolute'''
    token.transferRange(a[3], 2**48-20001, 2**48-10001, {'from': a[2]})
    _check(
        [(1, 2**48-20001)],
        [],
        [(2**48-20001, 2**48-1)],
        []
    )


def whole_range_same_both():
    '''whole range, merge both sides, absolute both'''
    token.transferRange(a[3], 1, 2**48-20001, {'from': a[1]})
    token.transferRange(a[3], 2**48-20001, 2**48-10001, {'from': a[2]})
    _check(
        [],
        [],
        [(1, 2**48-1)],
        []
    )


def whole_range_same_right():
    '''whole range, merge both sides, absolute right'''
    token.transferRange(a[3], 5000, 2**48-20001, {'from': a[1]})
    token.transferRange(a[3], 2**48-20001, 2**48-10001, {'from': a[2]})
    _check(
        [(1, 5000)],
        [],
        [(5000, 2**48-1)],
        []
    )


def stop_absolute():
    '''partial, touch stop, absolute'''
    token.transferRange(a[4], 2**48-5000, 2**48-1, {'from': a[3]})
    _check(
        [(1, 2**48-20001)],
        [(2**48-20001, 2**48-10001)],
        [(2**48-10001, 2**48-5000)],
        [(2**48-5000, 2**48-1)]
    )


def stop_partial_same_abs():
    '''partial, touch stop, merge, absolute'''
    token.transferRange(a[3], 2**48-15000, 2**48-10001, {'from': a[2]})
    _check(
        [(1, 2**48-20001)],
        [(2**48-20001, 2**48-15000)],
        [(2**48-15000, 2**48-1)],
        []
    )


def _check(*expected_ranges):
    for num, expected in enumerate(expected_ranges, start=1):
        account = a[num]
        ranges = token.rangesOf(account)
        check.equal(set(ranges),set(expected))
        check.equal(
            token.balanceOf(account),
            sum((i[1] - i[0]) for i in ranges)
        )
        for start, stop in ranges:
            if stop-start == 1:
                check.equal(token.getRange(start)[:3],(account, start, stop))
                continue
            for i in range(max(1, start-1),start+2):
                try:
                    data = token.getRange(i)
                except:
                    raise AssertionError("Could not get range pointer {} for account {}".format(i, num))
                if i < start:
                    check.true(data[0] != account)
                    check.true(data[2] == start)
                else:
                    check.true(data[0] == account)
                    check.true(data[2] == stop)
            for i in range(stop-1,min(stop+2,upper)):
                data = token.getRange(i)
                if i < stop:
                    check.true(data[0] == account)
                    check.true(data[1] == start)
                else:

                    check.true(data[0] != account)
                    check.true(data[1] == stop)