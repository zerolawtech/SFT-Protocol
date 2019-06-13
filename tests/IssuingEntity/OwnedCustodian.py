#!/usr/bin/python3

from brownie import *
from scripts.deployment import main

source = '''pragma solidity 0.4.25;

contract TestCustodian {

    bytes32 public ownerID = 0x1234;

    function setID (bytes32 _id) public { ownerID = _id; }

}'''


def setup():
    global token, issuer, TestCustodian, cust
    token, issuer, _ = main(SecurityToken, (1,2), (1,))
    TestCustodian = compile_source(source)[0]
    cust = a[0].deploy(TestCustodian)


def add():
    '''add custodian'''
    issuer.addCustodian(cust, {'from': a[0]})
    check.equal(issuer.getID(cust), cust.ownerID())


def add_twice():
    '''add custodian - already added'''
    issuer.addCustodian(cust, {'from': a[0]})
    check.reverts(
        issuer.addCustodian,
        (cust, {'from': a[0]}),
        "dev: known address"
    )
    c = a[1].deploy(TestCustodian)
    check.reverts(
        issuer.addCustodian,
        (c, {'from': a[0]}),
        "dev: known ID"
    )


def add_zero_id():
    '''add custodian - zero id'''
    cust.setID(0, {'from': a[0]})
    check.reverts(
        issuer.addCustodian,
        (cust, {'from': a[0]}),
        "dev: zero ID"
    )


def add_investor_id():
    '''custodian / investor collision - investor seen first'''
    token.mint(a[2], 100, {'from': a[0]})
    id_ = issuer.getID.call(a[2])
    cust.setID(id_, {'from': a[0]})
    check.reverts(
        issuer.addCustodian,
        (cust, {'from': a[0]}),
        "dev: known ID"
    )

def add_investor_id2():
    '''custodian / investor collision - custodian seen first'''
    token.mint(issuer, 100, {'from': a[0]})
    id_ = issuer.getID.call(a[2])
    cust.setID(id_, {'from': a[0]})
    issuer.addCustodian(cust, {'from': a[0]})
    check.reverts(
        token.transfer,
        (a[2], 100, {'from': a[0]})
    )

def cust_auth_id():
    '''custodian / authority collisions'''
    issuer.addAuthority([a[-1]], [], 2000000000, 1, {'from': a[0]})
    id_ = issuer.getID(a[-1])
    cust.setID(id_, {'from': a[0]})
    check.reverts(
        issuer.addCustodian,
        (cust, {'from': a[0]}),
        "dev: authority ID"
    )
    rpc.revert()
    cust.setID(id_, {'from': a[0]})
    issuer.addCustodian(cust, {'from': a[0]})
    check.reverts(
        issuer.addAuthority,
        ([a[-1]], [], 2000000000, 1, {'from': a[0]}),
        "dev: known ID"
    )

