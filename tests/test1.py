


def test(network, accounts):
    kyc = network.KYCRegistrar
    x =kyc.functions.addInvestor(b"investor2", 1, 0, 2, 9999999999, [accounts[3]]).transact({'from':accounts[0]})
    #print(web3.toHex(x))
    y = kyc.functions.addInvestor(b"investor2", 1, 0, 2, 9999999999, [accounts[4]]).transact({'from':accounts[1]})
    #print(web3.toHex(y))