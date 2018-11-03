

import random

NO_SETUP = True

REGISTRIES = 3
ISSUERS = 5
TOKENS = (2,6)
COUNTRIES = 3
RATINGS = 3

kyc = []
issuers = []
investors = [] # {'id':None, 'country':0, 'rating':0, 'accounts':[], 'kyc':[]}

def deplsoy(network, accounts):
    
    """Create a diverse ecosystem"""
    # create investors
    print("Creating investors...")
    for i in range(2, len(accounts)):
        if len(investors) < 1 or random.random()<0.66:
            investors.append({
                'id':"investor{}".format(i).encode(),
                'country':random.randint(1,COUNTRIES),
                'rating':random.randint(1,RATINGS),
                'accounts':[accounts[i]],
                'kyc':set()
            })
        else:
            investors[-1]['accounts'].append(accounts[i])

    # deploy KYCRegistry contracts, add investors
    print("Deploying registries and adding investors...")
    for i in range(REGISTRIES):
        kyc.append(network.deploy("KYCRegistrar", [accounts[0]],
                                  b"kyc"+bytes(i), 1))
        for inv in investors:
            if random.random() > 0.66:
                continue
            kyc[-1].addInvestor(inv['id'], inv['country'], 0,
                                inv['rating'], 9999999999, inv['accounts'])
            inv['kyc'].add(i)
    
    # deploy IssuingEntity and SecurityToken contracts, associate tokens and registries
    print("Deploying IssuingEntities and SecurityTokens...")
    for i in range(ISSUERS):
        issuer = network.deploy("IssuingEntity", [accounts[1]],
                                1, {'from':accounts[1]})
        issuers.append(issuer)
        issuer.tokens = []
        issuer.kyc = set()
        issuer.countries = [{'allowed':False}]
        for t in range(random.randint(TOKENS[0], TOKENS[1])):
            ts = random.randint(1000000,10000000000)
            issuer.tokens.append(network.deploy("SecurityToken", issuer.address,
                                 "Token", "ST", ts, {'from':accounts[1]}))
            issuer.tokens[-1].balances = dict((i,0) for i in accounts[2:])
            issuer.tokens[-1].balances[accounts[1]] = ts
            issuer.addToken(issuer.tokens[-1].address)
        for k in range(len(kyc)):
            if random.random() > 0.66:
                continue
            issuer.addRegistrar(kyc[k].address)
            issuer.kyc.add(k)
        for c in range(1,COUNTRIES+1):
            if random.random() > 0.66:
                issuer.countries.append({'allowed':False})
                continue
            country = {
                'minRating':random.randint(1,RATINGS),
                'count':0,
                'limit':random.randint(1,len(investors)),
                'allowed':True
            }
            issuer.countries.append(country)
            issuer.setCountries([c], [country['minRating']], [country['limit']])
            assert (issuer.getCountryInvestorLimit(c, 0) == country['limit'])
    
    print("Distributing tokens from issuer to investors...")
    for issuer, token in [(k,x) for k in issuers for x in k.tokens]:
        _id = issuer.issuerID()
        for i in investors:
            allowed = _is_allowed(issuer, i)
            try:
                value = random.randint(1,token.balances[accounts[1]])
                to = random.choice(i['accounts'])
                token.transfer(to, value)
                assert allowed == True, (
                    "Transfer should have failed - {}".format(allowed))
                token.balances[accounts[1]] -= value
                if _investor_balance(issuer, i) == 0:
                    issuer.countries[i['country']]['count'] += 1
                token.balances[to] += value
            except ValueError:
                assert allowed != True, "Transfer should have succeeded"
                continue
            assert token.balanceOf(to) == token.balances[to], (
                "Incorrect issuer Balance")
            assert token.balanceOf(issuer.address) == token.balances[accounts[1]]
            assert issuer.balanceOf(i['id']) == _investor_balance(issuer, i)
            assert issuer.balanceOf(_id) == sum(t.balances[accounts[1]] for t in issuer.tokens)
            assert issuer.getCountryInvestorCount(i['country'],0) == issuer.countries[i['country']]['count']


def _is_allowed(issuer, investor):
    c = issuer.countries[investor['country']]
    if not c['allowed']:
        return "Country is not allowed"
    if c['count'] == c['limit'] and _investor_balance(issuer, investor) == 0:
        return "Investor limit reached"
    if c['minRating'] > investor['rating']:
        return "Investor rating too low"
    if not issuer.kyc.intersection(investor['kyc']):
        return "No KYC"
    return True

def _investor_balance(issuer, investor):
    total = 0
    for account in investor['accounts']:
        total += sum(t.balances[account] for t in issuer.tokens)
    return total