
import itertools

def deploy(network, accounts):
    kyc = network.deploy('KYCRegistrar', [accounts[0]], 0)
    issuer = network.deploy('IssuingEntity', [accounts[1]], 1, {'from': accounts[1]})
    token = network.deploy('SecurityToken', issuer.address, "Test Token", "TST", 1000000, {'from':accounts[1]})
    issuer.addToken(token.address)
    for count,country,rating in [(c,i[0],i[1]) for c,i in enumerate(itertools.product([1,2,3], [1,2]), start=2)]:
        kyc.addInvestor(b"investor"+str(count).encode(), country, 0, rating, 9999999999, [accounts[count]])
    