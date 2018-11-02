


def setup(network, accounts):
    network.deploy('KYCRegistrar', [accounts[0]], b"kyc", 0)
    issuer = network.deploy('IssuingEntity', [accounts[1]], 1, **{'from': accounts[1]})
    token = network.deploy('SecurityToken', issuer.address, "Test Token", "TST", 1000000, **{'from':accounts[1]})
    issuer.functions.addToken(token.address).transact({'from':accounts[1]})