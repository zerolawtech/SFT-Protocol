from brownie import *
from scripts.deployment import main


def setup():
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

def inside():
    '''inside'''
    token.transferRange(a[4], 12000, 13000, {'from': a[2]})
    _check(
        [(1,10001)],
        [(10001, 12000),(13000,20001)],
        [(20001, 30001)],
        [(12000, 13000)]
    )

def start_partial_different():
    '''partial, touch start, no merge'''
    token.transferRange(a[4], 10001, 11001, {'from': a[2]})
    _check(
        [(1, 10001)],
        [(11001, 20001)],
        [(20001, 30001)],
        [(10001, 11001)]
    )

def start_partial_same():
    '''partial, touch start, merge, absolute'''
    token.transferRange(a[1], 10001, 11001, {'from': a[2]})
    _check(
        [(1, 11001)],
        [(11001, 20001)],
        [(20001, 30001)],
        []
    )

def start_partial_same_abs():
    '''partial, touch start, merge'''
    token.transferRange(a[3], 1, 5000, {'from': a[1]})
    token.transferRange(a[1], 10001, 11001, {'from': a[2]})
    _check(
        [(5000, 11001)],
        [(11001, 20001)],
        [(1, 5000), (20001, 30001)],
        []
    )

def start_absolute():
    '''touch start, absolute'''
    token.transferRange(a[4], 1, 100, {'from': a[1]})
    _check(
        [(100, 10001)],
        [(10001, 20001)],
        [(20001, 30001)],
        [(1,100)]
    )

def stop_partial_different():
    '''partial, touch stop, no merge'''
    token.transferRange(a[4], 19000, 20001, {'from': a[2]})
    _check(
        [(1, 10001)],
        [(10001, 19000)],
        [(20001, 30001)],
        [(19000, 20001)]
    )
    

def stop_partial_same_abs():
    '''partial, touch stop, merge, absolute'''
    token.transferRange(a[3], 19000, 20001, {'from': a[2]})
    _check(
        [(1, 10001)],
        [(10001, 19000)],
        [(19000, 30001)],
        []
    )

def stop_partial_same():
    '''partial, touch stop, merge'''
    token.transferRange(a[1], 25000, 30001, {'from': a[3]})
    token.transferRange(a[3], 19000, 20001, {'from': a[2]})
    _check(
        [(1, 10001),(25000, 30001)],
        [(10001, 19000)],
        [(19000, 25000)],
        []
    )

def stop_absolute():
    '''partial, touch stop, absolute'''
    token.transferRange(a[4], 29000, 30001, {'from': a[3]})
    _check(
        [(1, 10001)],
        [(10001, 20001)],
        [(20001, 29000)],
        [(29000, 30001)]
    )

def whole_range_different():
    '''whole range, no merge'''
    token.transferRange(a[4], 10001, 20001, {'from': a[2]})
    _check(
        [(1, 10001)],
        [],
        [(20001, 30001)],
        [(10001, 20001)]
    )


def whole_range_same():
    '''whole range, merge both sides'''
    token.transferRange(a[3], 5000, 10001, {'from': a[1]})
    token.transferRange(a[1], 25001, 30001, {'from': a[3]})
    token.transferRange(a[3], 10001, 20001, {'from': a[2]})
    _check(
        [(1, 5000), (25001, 30001)],
        [],
        [(5000, 25001)],
        []
    )

def whole_range_same_left():
    '''whole range, merge both sides, absolute left'''
    token.transferRange(a[1], 20001, 25000, {'from': a[3]})
    token.transferRange(a[1], 10001, 20001, {'from': a[2]})
    _check(
        [(1, 25000)],
        [],
        [(25000, 30001)],
        []
    )

def whole_range_same_right():
    '''whole range, merge both sides, absolute right'''
    token.transferRange(a[3], 5000, 10001, {'from': a[1]})
    token.transferRange(a[3], 10001, 20001, {'from': a[2]})
    _check(
        [(1, 5000)],
        [],
        [(5000, 30001)],
        []
    )

def whole_range_same_both():
    '''whole range, merge both sides, absolute both'''
    token.transferRange(a[3], 1, 10001, {'from': a[1]})
    token.transferRange(a[3], 10001, 20001, {'from': a[2]})
    _check(
        [],
        [],
        [(1, 30001)],
        []
    )


def whole_range_left_abs():
    '''whole range, merge left, absolute'''
    token.transferRange(a[1], 10001, 20001, {'from': a[2]})
    _check(
        [(1, 20001)],
        [],
        [(20001, 30001)],
        []
    )

def whole_range_left():
    '''whole range, merge left'''
    token.transferRange(a[3], 1, 5001, {'from': a[1]})
    token.transferRange(a[1], 10001, 20001, {'from': a[2]})
    _check(
        [(5001, 20001)],
        [],
        [(1, 5001), (20001, 30001)],
        []
    )

def whole_range_right_abs():
    '''whole range, merge right, absolute'''
    token.transferRange(a[3], 10001, 20001, {'from': a[2]})
    _check(
        [(1, 10001)],
        [],
        [(10001, 30001)],
        []
    )

def whole_range_right():
    '''whole range, merge right'''
    token.transferRange(a[1], 25001, 30001, {'from': a[3]})
    token.transferRange(a[3], 10001, 20001, {'from': a[2]})
    _check(
        [(1, 10001), (25001, 30001)],
        [],
        [(10001, 25001)],
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