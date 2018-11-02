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
    await token.contract.transfer(to, value, {from: from});   
  } catch(e) {
    return false;
  };
  token.balances[from] -= value;
  if (token.balances[to] == undefined) {
    token.balances[to] = value;
  } else {
    token.balances[to] += value;
  }
  return true;
}

async function isAllowed(investor) {
  let c = countries[investor.country];
  if (c.minRating > investor.rating) { return false; }
  if (!c.allowed) { return false; }
  if (c.count >= c.limit) { return false; }
  for (i = 0; i < investor.kyc.length; i++) {
    if (!kyc[investor.kyc[i]].active) continue;
    return true;
  }
  return false;
}

async function getCount(token, country, rating) {
  // figure out investor counts
}

function randC(num) {
  return Math.ceil(Math.random()*num);
}

function randF(num) {
  return Math.floor(Math.random()*num);
}

var kyc = [];
var issuer;
var issuerAccount;
var tokens = [];
var investors = [{id:"issuer"}];
var countries = [{}];

for (var i = 0; i < COUNTRIES; i++) {
  countries.push({minRating: 0, allowed: false, count: 0, limit: 0});
}


contract('SecurityToken', async (accounts) => {
  
  it('Should deploy KYC contracts and whitelist accounts', async() => {    
    investors[0].accounts = [accounts[1]];
    issuerAccount = accounts[1];
    for (var i = 2; i < accounts.length; i++) {
      if (investors.length == 1 || Math.random() > 0.33) {
        investors.push({
          id:"investor"+i,
          country:randC(COUNTRIES),
          rating:randC(RATINGS),
          accounts:[accounts[i]],
          kyc:[]
        });
      } else {
        investors.slice(-1)[0].accounts.push(accounts[i]);
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
        await kyc[i].contract.addInvestor(investors[k].id, investors[k].country, 0, investors[k].rating, 9999999999, investors[k].accounts, {from: accounts[0]});
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
        active: true,
        balances: {}
      });
      tokens.slice(-1)[0].balances[investors[0].accounts[0]] = 1000000;
      await issuer.addToken(tokens.slice(-1)[0].contract.address, {from: accounts[1]});
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
      countries[i].minRating = randC(RATINGS);
      countries[i].limit = randC(investors.length);
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
        let receiver = investors[i].accounts[randF(investors[i].accounts.length)];
        let value = randC(tokens[t].balances[issuerAccount]);
        let result = await transfer(tokens[t], issuerAccount, receiver, value);
        if (expected != result) {
          console.log(investors[i]);
          console.log(countries[investors[i].country]);
        }
        assert.equal(result, expected);
        if (result) {
          let x = await tokens[t].contract.balanceOf(receiver);
          assert.equal(x.valueOf(), tokens[t].balances[receiver], "Receiver balance is wrong");
          x = await tokens[t].contract.balanceOf(issuer.address);
          assert.equal(x.valueOf(), tokens[t].balances[issuerAccount], "Issuer balance is wrong");
         // check balance in issuer contract
          // check investor counts
          // check total supply
        }
      }
    }
  })

});