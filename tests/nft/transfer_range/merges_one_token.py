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
    _check(
        [(1, 10001)],
        [(10001, 20001)],
        [(20001, 30001)],
        []
    )


def verify_initial():
    '''verify initial ranges'''
    _check(
        [(1, 10001)],
        [(10001, 20001)],
        [(20001, 30001)],
        []
    )


def inside_one():
    '''inside, one token'''
    token.transferRange(a[4], 12000, 12001, {'from': a[2]})
    _check(
        [(1,10001)],
        [(10001, 12000),(12001,20001)],
        [(20001, 30001)],
        [(12000, 12001)]
    )


def one_left():
    '''one token, touch left'''
    token.transferRange(a[4], 10001, 10002, {'from': a[2]})
    _check(
        [(1,10001)],
        [(10002, 20001)],
        [(20001, 30001)],
        [(10001, 10002)]
    )


def one_left_abs():
    '''one token, touch left, absolute'''
    token.transferRange(a[4], 1, 2, {'from': a[1]})
    _check(
        [(2,10001)],
        [(10001, 20001)],
        [(20001, 30001)],
        [(1, 2)]
    )


def one_left_merge():
    '''one token, touch left, merge'''
    token.transferRange(a[4], 1, 5000, {'from': a[1]})
    token.transferRange(a[1], 10001, 10002, {'from': a[2]})
    _check(
        [(5000,10002)],
        [(10002, 20001)],
        [(20001, 30001)],
        [(1, 5000)]
    )


def one_left_merge_abs():
    '''one token, touch left, merge, absolute'''
    token.transferRange(a[1], 10001, 10002, {'from': a[2]})
    _check(
        [(1,10002)],
        [(10002, 20001)],
        [(20001, 30001)],
        []
    )


def one_right():
    '''one token, touch right'''
    token.transferRange(a[4], 20000, 20001, {'from': a[2]})
    _check(
        [(1,10001)],
        [(10001, 20000)],
        [(20001, 30001)],
        [(20000, 20001)]
    )


def one_right_abs():
    '''one token, touch right, absolute'''
    token.transferRange(a[4], 30000, 30001, {'from': a[3]})
    _check(
        [(1,10001)],
        [(10001, 20001)],
        [(20001, 30000)],
        [(30000, 30001)]
    )


def one_right_merge():
    '''one token touch right, merge'''
    token.transferRange(a[4], 25000, 30001, {'from': a[3]})
    token.transferRange(a[3], 20000, 20001, {'from': a[2]})
    _check(
        [(1,10001)],
        [(10001, 20000)],
        [(20000, 25000)],
        [(25000, 30001)]
    )


def one_right_merge_abs():
    '''one token, touch right, merge absolute'''
    token.transferRange(a[3], 20000, 20001, {'from': a[2]})
    _check(
        [(1,10001)],
        [(10001, 20000)],
        [(20000, 30001)],
        []
    )


def create_one_start():
    '''create one token range at start'''
    token.transferRange(a[4], 10002, 12001, {'from': a[2]})
    _check(
        [(1, 10001)],
        [(10001, 10002), (12001, 20001)],
        [(20001, 30001)],
        [(10002, 12001)]
    )


def create_one_start_abs():
    '''create one token range at start, absolute'''
    token.transferRange(a[4], 2, 1000, {'from': a[1]})
    _check(
        [(1, 2), (1000, 10001)],
        [(10001, 20001)],
        [(20001, 30001)],
        [(2, 1000)]
    )


def create_one_end():
    '''create one token range at end'''
    token.transferRange(a[4], 19000, 20000, {'from': a[2]})
    _check(
        [(1, 10001)],
        [(10001, 19000), (20000, 20001)],
        [(20001, 30001)],
        [(19000, 20000)]
    )


def create_one_end_abs():
    '''create one token range at end, absolute'''
    token.transferRange(a[4], 29000, 30000, {'from': a[3]})
    _check(
        [(1, 10001)],
        [(10001, 20001)],
        [(20001, 29000), (30000, 30001)],
        [(29000, 30000)]
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
            for i in range(stop-1,min(stop+1,upper)):
                data = token.getRange(i)
                if i < stop:
                    check.true(data[0] == account)
                    check.true(data[1] == start)
                else:

                    check.true(data[0] != account)
                    check.true(data[1] == stop)