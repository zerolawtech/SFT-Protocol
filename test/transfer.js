const KYCRegistrar = artifacts.require("KYCRegistrar");
const IssuingEntity = artifacts.require("IssuingEntity");
const SecurityToken = artifacts.require("SecurityToken");


investors = [
  {country: 0, rating: 0, balance: 0},
  {country: 0, rating: 0, balance: 1000000},
  {country: 1, rating: 1, balance: 0},
  {country: 1, rating: 2, balance: 0},
  {country: 2, rating: 1, balance: 0},
  {country: 2, rating: 2, balance: 0},
  {country: 3, rating: 1, balance: 0},
  {country: 3, rating: 2, balance: 0},
  {country: 1, rating: 1, balance: 0},
  {country: 3, rating: 2, balance: 0},
  {country: 1, rating: 2, balance: 0},
]

async function getCount(country, rating) {
  var count = 0;
  for (var i = 2; i < investors.length; i++) {
    if (investors[i].balance == 0) continue;
    if ((country == 0 || investors[i].country == country) 
      && (rating == 0 || investors[i].rating == rating)) {
      count++;
    }
  }
  return count;
}

async function performChecks(token, issuer, accounts) {
  var id, x, c;
  c = 0;
  for (i = 2; i < investors.length; i++) {
    if (investors[i].balance > 0) {
      c++;
    }
    x = await token.balanceOf(accounts[i]);
    assert.equal(x.valueOf(), investors[i].balance,
                 "Incorrect balance in SecurityToken: Account "+i);
    //x = await issuer.balanceOf(investors[i].id);
    //assert.equal(x.valueOf(), investors[i].balance,
    //             "Incorrect balance in IssuingEntity: Account "+i);
  }
  x = await token.treasurySupply();
  assert.equal(x.valueOf(), investors[1].balance, "Teasury supply is wrong");
  x = await issuer.totalInvestors();
  assert.equal(x.valueOf(), c, "Total investor count is wrong");
  for (i = 1; i < 3; i++) {
    for (k = 0; k < 3; k++) {
      x = await issuer.getCountryInvestorCount(i, k);
      assert.equal(x.valueOf(), await getCount(i ,k), i+" "+k+" Country investor rating count is wrong");
    }
  }
};

async function transfer(token, accounts, from, to, value) {
  try {
    await token.transfer(accounts[to], value, {from: accounts[from]});   
  } catch(e) {
    return false;
  };
  investors[from].balance -= value;
  investors[to].balance += value;
  return true;
}

async function transferFrom(token, accounts, auth, from, to, value) {
  try {
    await token.transferFrom(accounts[from], accounts[to], value, {from: accounts[auth]});
  } catch(e) {
    return false;
  };
  investors[from].balance -= value;
  investors[to].balance += value;
  return true;
}


contract('SecurityToken', async (accounts) => {
  
  it('Should approve countries 1 and 2', async() => {
    var error = "";
    let issuer = await IssuingEntity.deployed();
    try {
      await issuer.setCountries([1,2,3], [1,1,2], [2,2,2], {from: accounts[1]});   
    } catch(e) {
      error = e;
    };
    assert.equal(error, "", error);
    let country = await issuer.getCountryInfo(1,1);
    assert.equal(country[0].valueOf(), 0);
    assert.equal(country[1].valueOf(), 0);
  });

  it('1 => 2, registrar has not been set (should fail)', async() => {
    let kyc = await KYCRegistrar.deployed();
    for (var i = 2; i < investors.length; i++) {
      investors[i].id = await kyc.getId(accounts[i]);
    }
    let token = await SecurityToken.deployed();
    let issuer = await IssuingEntity.deployed();
    let result = await transfer(token, accounts, 1, 2, 1000);
    assert.equal(result, false, "Transfer should have failed.");
    await performChecks(token, issuer, accounts);
  });

  it('Should add registrar to IssuingEntity', async() => {
    var error = "";
    let issuer = await IssuingEntity.deployed();
    let registrar = await KYCRegistrar.deployed();
    try {
      await issuer.addRegistrar(registrar.address, {from: accounts[1]});   
    } catch(e) {
      error = e;
    };
    assert.equal(error, "", error);
  });

  it('1 => 2 (should succeed)', async() => {
    let token = await SecurityToken.deployed();
    let issuer = await IssuingEntity.deployed();
    let result = await transfer(token, accounts, 1, 2, 1000);
    assert.equal(result, true, "Transfer should have succeeded.");
    await performChecks(token, issuer, accounts);
  });

  it('1 => 3 (should succeed)', async() => {
    let token = await SecurityToken.deployed();
    let issuer = await IssuingEntity.deployed();
    let result = await transfer(token, accounts, 1, 3, 700);
    assert.equal(result, true, "Transfer should have succeeded.");
    await performChecks(token, issuer, accounts);
  });

  it('3 => 10 transferFrom as 10 (should succeed)', async() => {
    let token = await SecurityToken.deployed();
    let issuer = await IssuingEntity.deployed();
    let result = await transferFrom(token, accounts, 10, 3, 10, investors[3].balance);
    assert.equal(result, true, "Transfer should have succeeded.");
    await performChecks(token, issuer, accounts);
  });

  it('10 => 3 transferFrom as 3 (should succeed)', async() => {
    let token = await SecurityToken.deployed();
    let issuer = await IssuingEntity.deployed();
    let result = await transferFrom(token, accounts, 3, 10, 3, investors[10].balance);
    assert.equal(result, true, "Transfer should have succeeded.");
    await performChecks(token, issuer, accounts);
  });

  it('1 => 5 (should succeed)', async() => {
    let token = await SecurityToken.deployed();
    let issuer = await IssuingEntity.deployed();
    let result = await transfer(token, accounts, 1, 5, 6000);
    assert.equal(result, true, "Transfer should have succeeded.");
    await performChecks(token, issuer, accounts);
  });

  it('2 => 3, 0 token transfer (should fail)', async() => {
    let token = await SecurityToken.deployed();
    let issuer = await IssuingEntity.deployed();
    let result = await transfer(token, accounts, 2, 3, 0);
    assert.equal(result, false, "Transfer should have failed.");
    await performChecks(token, issuer, accounts);
  });

  it('2 => 3, send more than total balance (should fail)', async() => {
    let token = await SecurityToken.deployed();
    let issuer = await IssuingEntity.deployed();
    let result = await transfer(token, accounts, 2, 3, investors[2].balance+10);
    assert.equal(result, false, "Transfer should have failed.");
    await performChecks(token, issuer, accounts);
  });

  it('2 => 3 (should succeed)', async() => {
    let token = await SecurityToken.deployed();
    let issuer = await IssuingEntity.deployed();
    let result = await transfer(token, accounts, 2, 3, investors[2].balance);
    assert.equal(result, true, "Transfer should have succeeded.");
    await performChecks(token, issuer, accounts);
  });

  it('3 => 9, restricted receiver (should fail)', async() => {
    let token = await SecurityToken.deployed();
    let issuer = await IssuingEntity.deployed();
    let result = await transfer(token, accounts, 1, 9, 50);
    assert.equal(result, false, "Transfer should have failed.");
    await performChecks(token, issuer, accounts);
  });

  it('4 => 6, send has no balance (should fail)', async() => {
    let token = await SecurityToken.deployed();
    let issuer = await IssuingEntity.deployed();
    let result = await transfer(token, accounts, 4, 6, 50);
    assert.equal(result, false, "Transfer should have failed.");
    await performChecks(token, issuer, accounts);
  });

  it('1 => 6, min rating too low (should fail)', async() => {
    let token = await SecurityToken.deployed();
    let issuer = await IssuingEntity.deployed();
    let result = await transfer(token, accounts, 1, 6, 500);
    assert.equal(result, false, "Transfer should have failed.");
    await performChecks(token, issuer, accounts);
  });

  it('1 => 8, receiver kyc expired (should fail)', async() => {
    let token = await SecurityToken.deployed();
    let issuer = await IssuingEntity.deployed();
    let result = await transfer(token, accounts, 1, 6, 500);
    assert.equal(result, false, "Transfer should have failed.");
    await performChecks(token, issuer, accounts);
  });

  it('3 => 2, transferFrom as account 1 (should succeed)', async() => {
    let token = await SecurityToken.deployed();
    let issuer = await IssuingEntity.deployed();
    let result = await transferFrom(token, accounts, 1, 3, 2, 50);
    assert.equal(result, true, "Transfer should have succeeded.");
    await performChecks(token, issuer, accounts);
  });

  it('3 => 2, transferFrom as account 4 (should fail)', async() => {
    let token = await SecurityToken.deployed();
    let issuer = await IssuingEntity.deployed();
    let result = await transferFrom(token, accounts, 4, 3, 2, 50);
    assert.equal(result, false, "Transfer should have failed.");
    await performChecks(token, issuer, accounts);
  });

  

});