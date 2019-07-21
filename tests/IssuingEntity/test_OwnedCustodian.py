#!/usr/bin/python3

import pytest

from brownie import accounts, compile_source

source = '''pragma solidity 0.4.25;

contract TestCustodian {

    bytes32 public ownerID = 0x1234;

    function setID (bytes32 _id) public { ownerID = _id; }

}'''


@pytest.fixture(scope="module")
def TestCustodian():
    yield compile_source(source)[0]


@pytest.fixture(scope="module")
def testcust(TestCustodian):
    cust = accounts[0].deploy(TestCustodian)
    yield cust


def test_add(id1, id2, issuer, testcust):
    '''add custodian'''
    issuer.addCustodian(testcust, {'from': accounts[0]})
    assert issuer.getID(testcust) == testcust.ownerID()


def test_add_twice(issuer, testcust, TestCustodian):
    '''add custodian - already added'''
    issuer.addCustodian(testcust, {'from': accounts[0]})
    with pytest.reverts("dev: known address"):
        issuer.addCustodian(testcust, {'from': accounts[0]})
    c = accounts[1].deploy(TestCustodian)
    with pytest.reverts("dev: known ID"):
        issuer.addCustodian(c, {'from': accounts[0]})


def test_add_zero_id(issuer, testcust):
    '''add custodian - zero id'''
    testcust.setID(0, {'from': accounts[0]})
    with pytest.reverts("dev: zero ID"):
        issuer.addCustodian(testcust, {'from': accounts[0]})


def test_add_investor_id(token, issuer, testcust):
    '''custodian / investor collision - investor seen first'''
    token.mint(accounts[2], 100, {'from': accounts[0]})
    id_ = issuer.getID.call(accounts[2])
    testcust.setID(id_, {'from': accounts[0]})
    with pytest.reverts("dev: known ID"):
        issuer.addCustodian(testcust, {'from': accounts[0]})


def test_add_investor_id2(token, issuer, testcust):
    '''custodian / investor collision - custodian seen first'''
    token.mint(issuer, 100, {'from': accounts[0]})
    id_ = issuer.getID.call(accounts[2])
    testcust.setID(id_, {'from': accounts[0]})
    issuer.addCustodian(testcust, {'from': accounts[0]})
    with pytest.reverts():
        token.transfer(accounts[2], 100, {'from': accounts[0]})


def test_cust_auth_id(issuer, token, testcust, rpc):
    '''custodian / authority collisions'''
    issuer.addAuthority([accounts[-1]], [], 2000000000, 1, {'from': accounts[0]})
    id_ = issuer.getID(accounts[-1])
    testcust.setID(id_, {'from': accounts[0]})
    with pytest.reverts("dev: authority ID"):
        issuer.addCustodian(testcust, {'from': accounts[0]})
    rpc.revert()
    testcust.setID(id_, {'from': accounts[0]})
    issuer.addCustodian(testcust, {'from': accounts[0]})
    with pytest.reverts("dev: known ID"):
        issuer.addAuthority([accounts[-1]], [], 2000000000, 1, {'from': accounts[0]})
