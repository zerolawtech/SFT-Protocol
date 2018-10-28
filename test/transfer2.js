const KYCRegistrar = artifacts.require("KYCRegistrar");
const IssuingEntity = artifacts.require("IssuingEntity");
const SecurityToken = artifacts.require("SecurityToken");

const INVESTOR_KYC_PCT = 0.66;
const KYC = 3;
const KYC_PCT = 0.66;
const COUNTRIES = 5;
const COUNTRY_PCT = 0.66;
const RATINGS = 3;
const TOKENS = 5;

async function transfer(token, from, to, value) {
  try {
    await tokens[token].contract.transfer(investors[to[0]].accounts[to[1]].addr, value, {from: investors[from[0]].accounts[from[1]].addr});   
  } catch(e) {
    return false;
  };
  investors[from[0]].accounts[from[1]].balances[token] -= value;
  investors[to[0]].accounts[to[1]].balances[token] += value;
  return true;
}

async function isAllowed(investor) {
  if (countries[investor.country].minRating > investor.rating) { return false; }
  if (!countries[investor.country].allowed) { return false; }
  if (countries[investor.country].count >= countries[investor.country].limit) { return false; }
  for (i = 0; i < investor.kyc.length; i++) {
    if (!kyc[investor.kyc[i]].active) continue;
    return true;
  }
  return false;
}


var kyc = [];
var issuer;
var tokens = [];
var investors = [{id:"issuer"}];
var countries = [{}];

for (var i = 0; i < COUNTRIES; i++) {
  countries.push({minRating: 0, allowed: false, count: 0, limit: 0});
}


contract('SecurityToken', async (accounts) => {
  
  it('Should deploy KYC contracts and whitelist accounts', async() => {    
    investors[0].accounts = [{addr:accounts[1], balances:Array(TOKENS).fill(0)}];
    for (var i = 2; i < accounts.length; i++) {
      if (investors.length == 1 || Math.random() > 0.33) {
        investors.push({
          id:"investor"+i,
          country:Math.ceil(Math.random()*COUNTRIES),
          rating:Math.ceil(Math.random()*RATINGS),
          accounts:[{addr:accounts[i], balances:Array(TOKENS).fill(0)}],
          kyc:[]
        });
      } else {
        investors.slice(-1)[0].accounts.push({addr:accounts[i], balances:Array(TOKENS).fill(0)});
      }
    }
    console.log("Total of "+investors.length+" unique investors.");
    
    for (var i = 0; i < KYC; i++) {
      kyc.push({
        contract: await KYCRegistrar.new([accounts[0]], "kyc"+i, 1, {from: accounts[0]}),
        active: false
      });
      for (var k = 1; k < investors.length; k++) {
        if (Math.random() > INVESTOR_KYC_PCT) continue;
        await kyc[i].contract.addInvestor(investors[k].id, investors[k].country, 0, investors[k].rating, 9999999999, investors[k].accounts.map(a => a.addr), {from: accounts[0]});
        investors[k].kyc.push(i);
      }
    }
  });

  it('Should deploy IssuingEntity and tokens, and associate contracts', async() => {
    issuer = await IssuingEntity.new([accounts[1]], 1, {from: accounts[1]});
    investors[0].id = await issuer.issuerID();
    for (i = 0; i < 5; i++) {
      tokens.push({
        contract: await SecurityToken.new(issuer.address, "Test Token "+i, "TS"+i, 1000000, {from: accounts[1]}),
        active: true
      });
      await issuer.addToken(tokens.slice(-1)[0].contract.address, {from: accounts[1]});
      investors[0].accounts[0].balances[i] = 1000000;
    }
    for (i = 0; i < kyc.length; i++) {
      if (Math.random() > KYC_PCT) continue;
      await issuer.addRegistrar(kyc[i].contract.address, {from: accounts[1]});
      kyc[i].active = true;
    }
  });

  it('Should approve countries', async() => {
    for (i = 1; i < countries.length; i++) {
      if (Math.random() > COUNTRY_PCT) continue;
      countries[i].minRating = Math.ceil(Math.random()*RATINGS);
      countries[i].limit = Math.ceil(Math.random()*investors.length);
      countries[i].allowed = true;
      await issuer.setCountries([i], [countries[i].minRating], [countries[i].limit], {from: accounts[1]});
      let x = await issuer.getCountryInvestorLimit(i, 0);
      assert.equal(x, countries[i].limit, "Country limit is wrong.");
    }
  });

  it("Should distrbute tokens from issuer to investors", async() => {
    for (var t = 0; t < tokens.length; t++) {
      for (var i = 1; i < investors.length; i++) {
        let expected = await isAllowed(investors[i]);
        let result = await transfer(t, [0,0], [i,Math.floor(Math.random()*investors[i].accounts.length)], Math.ceil(Math.random()*investors[0].accounts[0].balances[t]));
        if (expected != result) {
          console.log(investors[i], countries[investors[i].country]);
        }
        assert.equal(result, expected);
      }
    }
  })

});