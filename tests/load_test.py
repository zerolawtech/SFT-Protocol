

import random

from lib.components.eth import VirtualMachineError

NO_SETUP = True

REGISTRIES = 3
ISSUERS = 5
TOKENS = (2,6)
COUNTRIES = 3
RATINGS = 3

investors = [] # {'id':None, 'country':0, 'rating':0, 'accounts':[], 'kyc':[]}

def create_ecosystem():
    
    """Create a diverse ecosystem"""

    global a
    a = accounts

    # create investors
    for i in range(2, len(a)):
        if len(investors) < 1 or random.random()<0.66:
            investors.append({
                'id':"investor{}".format(i).encode(),
                'country':random.randint(1,COUNTRIES),
                'rating':random.randint(1,RATINGS),
                'accounts':[a[i]],
                'kyc':set()
            })
        else:
            investors[-1]['accounts'].append(a[i])

    # deploy KYCRegistry contracts, add investors
    for i in range(REGISTRIES):
        a[0].deploy(KYCRegistrar, [a[0]], 1)
        for inv in investors:
            if random.random() > 0.66:
                continue
            KYCRegistrar[-1].addInvestor(inv['id'], inv['country'], '0x00',
                                inv['rating'], 9999999999, inv['accounts'])
            inv['kyc'].add(i)
    
    # deploy IssuingEntity and SecurityToken contracts,
    # associate tokens and registries
    for i in range(ISSUERS):
        issuer = a[1].deploy(IssuingEntity, [a[1]], 1)
        issuer.tokens = []
        issuer.kyc = set()
        issuer.countries = [{'allowed':False}]
        for t in range(random.randint(TOKENS[0], TOKENS[1])):
            ts = random.randint(1000000,10000000000)
            issuer.tokens.append(a[1].deploy(SecurityToken, issuer.address,
                                 "Token", "ST", ts))
            issuer.tokens[-1].balances = dict((i,0) for i in a[2:])
            issuer.tokens[-1].balances[a[1]] = ts
            issuer.addToken(issuer.tokens[-1].address)
        for k in range(len(KYCRegistrar)):
            if random.random() > 0.66:
                continue
            issuer.setRegistrar(KYCRegistrar[k].address, True)
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
            check.equal(issuer.getCountry(c)[2][0], country['limit'], "Country limit is wrong")


def transfer_issuer_to_investors():
    '''Send Tokens from issuers to investors'''
    for issuer, token in [(k,x) for k in IssuingEntity for x in k.tokens]:
        _id = issuer.ownerID()
        for i in investors:
            allowed = _is_allowed(issuer, i)
            try:
                value = random.randint(1,token.balances[a[1]])
                to = random.choice(i['accounts'])
                token.transfer(to, value)
                check.true(allowed, "Transfer should have failed - {}".format(allowed))
                token.balances[a[1]] -= value
                if _investor_balance(issuer, i) == 0:
                    issuer.countries[i['country']]['count'] += 1
                token.balances[to] += value
            except VirtualMachineError:
                check.not_equal(allowed, True, "Transfer should have succeeded")
                continue
            check.equal(token.balanceOf(to), token.balances[to], "Incorrect issuer Balance")
            check.equal(token.balanceOf(issuer.address), token.balances[a[1]])
            check.equal(issuer.balanceOf(i['id']), _investor_balance(issuer, i))
            check.equal(issuer.balanceOf(_id), sum(t.balances[a[1]] for t in issuer.tokens))
            check.equal(issuer.getCountry(i['country'])[1][0], issuer.countries[i['country']]['count'])


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
