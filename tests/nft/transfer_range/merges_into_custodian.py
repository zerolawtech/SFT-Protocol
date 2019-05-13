from brownie import *
from scripts.deployment import main


def setup(always_transact=False):
    main(NFToken)
    global token, issuer, cust, upper
    token = NFToken[0]
    issuer = IssuingEntity[0]
    cust = OwnedCustodian.deploy(a[0], [a[0]], 1)
    issuer.addCustodian(cust, {'from': a[0]})
    token.mint(a[1], 10000, 0, "0x00", {'from': a[0]})
    token.mint(a[2], 10000, 0, "0x00", {'from': a[0]})
    token.mint(a[3], 10000, 0, "0x00", {'from': a[0]})
    
    upper = token.totalSupply()+1
    


def verify_initial():
    '''verify initial ranges'''
    _check(
        ([(1, 10001)], []),
        ([(10001, 20001)], []),
        ([(20001, 30001)], []),
    )

def inside():
    '''inside'''
    token.transferRange(cust, 12000, 13000, {'from': a[2]})
    _check(
        ([(1, 10001)], []),
        ([(10001, 12000),(13000,20001)], [(12000, 13000)]),
        ([(20001, 30001)], []),

    )

def start_partial_different():
    '''partial, touch start, no merge'''
    token.transferRange(cust, 10001, 11001, {'from': a[2]})
    _check(
        ([(1, 10001)], []),
        ([(11001, 20001)], [(10001, 11001)]),
        ([(20001, 30001)], [])
    )

def start_partial_same():
    '''partial, touch start, merge, absolute'''
    token.transferRange(cust, 1, 10001, {'from': a[1]})
    token.transferRange(a[1], 10001, 20001, {'from': a[2]})
    token.transferRange(cust, 10001, 11001, {'from': a[1]})
    
    _check(
        ([(11001, 20001)], [(1, 11001)]),
        ([], []),
        ([(20001, 30001)], [])
    )

def start_partial_same_abs():
    '''partial, touch start, merge'''
    token.transferRange(cust, 5000, 10001, {'from': a[1]})
    token.transferRange(a[1], 10001, 20001, {'from': a[2]})
    token.transferRange(cust, 10001, 11001, {'from': a[1]})
    _check(
        ([(1, 5000), (11001, 20001)], [(5000, 11001)]),
        ([], []),
        ([(20001, 30001)], [])
    )

def start_absolute():
    '''touch start, absolute'''
    token.transferRange(cust, 1, 100, {'from': a[1]})
    _check(
        ([(100, 10001)], [(1, 100)]),
        ([(10001, 20001)], []),
        ([(20001, 30001)], [])
    )

def stop_partial_different():
    '''partial, touch stop, no merge'''
    token.transferRange(cust, 19000, 20001, {'from': a[2]})
    _check(
        ([(1, 10001)], []),
        ([(10001, 19000)], [(19000, 20001)]),
        ([(20001, 30001)], [])
    )

def stop_partial_same_abs():
    '''partial, touch stop, merge, absolute'''
    token.transferRange(cust, 20001, 30001, {'from': a[3]})
    token.transferRange(a[3], 10001, 20001, {'from': a[2]})
    token.transferRange(cust, 19000, 20001, {'from': a[3]})
    _check(
        ([(1, 10001)], []),
        ([], []),
        ([(10001, 19000)], [(19000, 30001)])
    )


def stop_partial_same():
    '''partial, touch stop, merge'''
    token.transferRange(cust, 20001, 25000, {'from': a[3]})
    token.transferRange(a[3], 10001, 20001, {'from': a[2]})
    token.transferRange(cust, 19000, 20001, {'from': a[3]})
    _check(
        ([(1, 10001)], []),
        ([], []),
        ([(10001, 19000), (25000, 30001)], [(19000, 25000)])
    )


def stop_absolute():
    '''partial, touch stop, absolute'''
    token.transferRange(cust, 29000, 30001, {'from': a[3]})
    _check(
        ([(1, 10001)], []),
        ([(10001, 20001)], []),
        ([(20001, 29000)], [(29000, 30001)]),
    )


def whole_range_different():
    '''whole range, no merge'''
    token.transferRange(cust, 10001, 20001, {'from': a[2]})
    _check(
        ([(1, 10001)], []),
        ([], [(10001, 20001)]),
        ([(20001, 30001)], [])
    )


def whole_range_same():
    '''whole range, merge both sides'''
    token.transferRange(a[2], 5000, 10001, {'from': a[1]})
    token.transferRange(a[2], 20001, 25000, {'from': a[3]})
    token.transferRange(cust, 5000, 10001, {'from': a[2]})
    token.transferRange(cust, 20001, 25000, {'from': a[2]})
    token.transferRange(cust, 10001, 20001, {'from': a[2]})
    _check(
        ([(1, 5000)], []),
        ([], [(5000, 25000)]),
        ([(25000, 30001)], [])
    )

def whole_range_same_left():
    '''whole range, merge both sides, absolute left'''
    token.transferRange(a[2], 1, 10001, {'from': a[1]})
    token.transferRange(a[2], 20001, 25000, {'from': a[3]})
    token.transferRange(cust, 1, 10001, {'from': a[2]})
    token.transferRange(cust, 20001, 25000, {'from': a[2]})
    token.transferRange(cust, 10001, 20001, {'from': a[2]})
    _check(
        ([], []),
        ([], [(1, 25000)]),
        ([(25000, 30001)], [])
    )

def whole_range_same_right():
    '''whole range, merge both sides, absolute right'''
    token.transferRange(a[2], 5000, 10001, {'from': a[1]})
    token.transferRange(a[2], 20001, 30001, {'from': a[3]})
    token.transferRange(cust, 5000, 10001, {'from': a[2]})
    token.transferRange(cust, 20001, 30001, {'from': a[2]})
    token.transferRange(cust, 10001, 20001, {'from': a[2]})
    _check(
        ([(1, 5000)], []),
        ([], [(5000, 30001)]),
        ([], [])
    )

def whole_range_same_both():
    '''whole range, merge both sides, absolute both'''
    token.transferRange(a[2], 1, 10001, {'from': a[1]})
    token.transferRange(a[2], 20001, 30001, {'from': a[3]})
    token.transferRange(cust, 1, 10001, {'from': a[2]})
    token.transferRange(cust, 20001, 30001, {'from': a[2]})
    token.transferRange(cust, 10001, 20001, {'from': a[2]})
    _check(
        ([], []),
        ([], [(1, 30001)]),
        ([], [])
    )


def whole_range_left_abs():
    '''whole range, merge left, absolute'''
    token.transferRange(cust, 1, 10001, {'from': a[1]})
    token.transferRange(a[1], 10001, 20001, {'from': a[2]})
    token.transferRange(cust, 10001, 20001, {'from': a[1]})
    _check(
        ([], [(1, 20001)]),
        ([], []),
        ([(20001, 30001)], [])
    )

def whole_range_left():
    '''whole range, merge left'''
    token.transferRange(cust, 5000, 10001, {'from': a[1]})
    token.transferRange(a[1], 10001, 20001, {'from': a[2]})
    token.transferRange(cust, 10001, 20001, {'from': a[1]})
    _check(
        ([(1, 5000)], [(5000, 20001)]),
        ([], []),
        ([(20001, 30001)], [])
    )

def whole_range_right_abs():
    '''whole range, merge right, absolute'''
    token.transferRange(a[2], 20001, 30001, {'from': a[3]})
    token.transferRange(cust, 20001, 30001, {'from': a[2]})
    token.transferRange(cust, 10001, 20001, {'from': a[2]})
    _check(
        ([(1, 10001)], []),
        ([], [(10001, 30001)]),
        ([], [])
    )

def whole_range_right():
    '''whole range, merge right'''
    token.transferRange(a[2], 20001, 25000, {'from': a[3]})
    token.transferRange(cust, 20001, 25000, {'from': a[2]})
    token.transferRange(cust, 10001, 20001, {'from': a[2]})
    _check(
        ([(1, 10001)], []),
        ([], [(10001, 25000)]),
        ([(25000, 30001)], [])
    )

def _check(*expected_ranges):
    check.equal(
        token.balanceOf(cust),
        sum((x[1] - x[0]) for i in expected_ranges for x in i[1] if x)
    )
    for num, expected in enumerate(expected_ranges, start=1):
        held, custodied = expected
        address = a[num]
        ranges = token.rangesOf(address)
        check.equal(set(ranges),set(held))
        check.equal(
            token.balanceOf(address),
            sum((i[1] - i[0]) for i in held)
        )
        _compare_ranges(held, num, "0x0000000000000000000000000000000000000000")
        
        ranges = token.custodianRangesOf(address, cust)
        check.equal(set(ranges),set(custodied))
        check.equal(
            token.custodianBalanceOf(address, cust),
            sum((i[1] - i[0]) for i in custodied)
        )
        _compare_ranges(custodied, num, cust)


def _compare_ranges(ranges, num, custaddress):
    address = accounts[num]
    for start, stop in ranges:
        if stop-start == 1:
            check.equal(token.getRange(start),(address, start, stop, 0, "0x0000", custaddress))
            continue
        for i in range(max(1, start-1),start+2):
            try:
                data = token.getRange(i)
            except:
                raise AssertionError("Could not get range pointer {} for account {}".format(i, num))
            if i < start:
                check.true(data[0] != address or data[5] != custaddress)
                check.true(data[2] == start)
            else:
                check.true(data[0] == address and data[5] == custaddress)
                check.true(data[2] == stop)
        for i in range(stop-1,min(stop+2,upper)):
            data = token.getRange(i)
            if i < stop:
                check.true(data[0] == address and data[5] == custaddress)
                check.true(data[1] == start)
            else:

                check.true(data[0] != address or data[5] != custaddress)
                check.true(data[1] == stop)
        