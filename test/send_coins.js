const KYCRegistrar = artifacts.require("KYCRegistrar");
const IssuingEntity = artifacts.require("IssuingEntity");
const SecurityToken = artifacts.require("SecurityToken");





contract('SecurityToken', async (accounts) => {
  

  it('Should approve countries 1 and 2', async() => {
    var error = "";
    let token = await SecurityToken.deployed();
    let issuer = await IssuingEntity.deployed();
    try {
      await issuer.setCountries([1,2], [1,1], [2,2], {from: accounts[1]});   
    } catch(e) {
      error = e
    };
    assert.equal(
      error,
      "",
      error
    );
    let country = await issuer.getCountryInfo(1,1);
    assert.equal(country[0].valueOf(), 0);
    assert.equal(country[1].valueOf(), 0);
  });

  it('Should fail to transfer tokens from issuer to account 2', async() => {
    var error = "";
    let token = await SecurityToken.deployed();
    let issuer = await IssuingEntity.deployed();
    try {
      await token.transfer(accounts[2], 100, {from: accounts[1]});   
    } catch(e) {
      error = e.message.split('revert')[1].split('\n')[0];
    };
    assert.equal(
      error,
      "",
      error
    );
    let balance = await token.balanceOf(issuer.address);
    assert.equal(balance.valueOf(), 1000000, "Sender balance is wrong.");
    balance = await token.balanceOf(accounts[2]);
    assert.equal(balance.valueOf(), 0, "Receiver balance is wrong.");
  });

  it('Should add registrar to IssuingEntity', async() => {
    var error = "";
    let token = await SecurityToken.deployed();
    let issuer = await IssuingEntity.deployed();
    let registrar = await KYCRegistrar.deployed();
    try {
      await issuer.addRegistrar(registrar.address, {from: accounts[1]});   
    } catch(e) {
      error = e.message.split('revert')[1].split('\n')[0];
    };
    assert.equal(
      error,
      "",
      error
    );
  });

  it('Should transfer tokens from issuer to account 2', async() => {
    var error = "";
    let token = await SecurityToken.deployed();
    let issuer = await IssuingEntity.deployed();
    try {
      await token.transfer(accounts[2], 100, {from: accounts[1]});   
    } catch(e) {
      error = e
    };
    assert.equal(
      error,
      "",
      error
    );
    let balance = await token.balanceOf(issuer.address);
    assert.equal(balance.valueOf(), 1000000-100, "Sender balance is wrong.");
    balance = await token.balanceOf(accounts[2]);
    assert.equal(balance.valueOf(), 100, "Receiver balance is wrong.");
    let x = await issuer.totalInvestors();
    assert.equal(x.valueOf(), 1, "Investor count is wrong.");
    x = await issuer.getCountryInvestorCount(1,0);
    assert.equal(x.valueOf(), 1, "Country investor count is wrong.");
    x = await issuer.getCountryInvestorCount(1,1);
    assert.equal(x.valueOf(), 1, "Country investor rating count is wrong.");
  });

  it('Should transfer tokens from issuer to account 3', async() => {
    var error = "";
    let token = await SecurityToken.deployed();
    let issuer = await IssuingEntity.deployed();
    try {
      await token.transfer(accounts[3], 400, {from: accounts[1]});   
    } catch(e) {
      error = e
    };
    assert.equal(
      error,
      "",
      error
    );
    let balance = await token.balanceOf(issuer.address);
    assert.equal(balance.valueOf(), 1000000-500, "Sender balance is wrong.");
    balance = await token.balanceOf(accounts[3]);
    assert.equal(balance.valueOf(), 400, "Receiver balance is wrong.");
    let x = await issuer.totalInvestors();
    assert.equal(x.valueOf(), 2, "Investor count is wrong.");
    x = await issuer.getCountryInvestorCount(1,0);
    assert.equal(x.valueOf(), 2, "Country investor count is wrong.");
    x = await issuer.getCountryInvestorCount(1,2);
    assert.equal(x.valueOf(), 1, "Country investor rating count is wrong.");
  });

  it('Should transfer tokens from account 2 to account 3', async() => {
    var error = "";
    let token = await SecurityToken.deployed();
    let issuer = await IssuingEntity.deployed();
    try {
      await token.transfer(accounts[3], 50, {from: accounts[2]});   
    } catch(e) {
      error = e
    };
    assert.equal(
      error,
      "",
      error
    );
    let x = await token.balanceOf(accounts[2]);
    assert.equal(x.valueOf(), 50, "Sender balance is wrong.");
    x = await token.balanceOf(accounts[3]);
    assert.equal(x.valueOf(), 450, "Receiver balance is wrong.");
    x = await issuer.totalInvestors();
    assert.equal(x.valueOf(), 2, "Investor count is wrong.");
    x = await issuer.getCountryInvestorCount(1,0);
    assert.equal(x.valueOf(), 2, "Country investor count is wrong.");
    x = await issuer.getCountryInvestorCount(1,2);
    assert.equal(x.valueOf(), 1, "Country investor rating count is wrong.");
  });

  it('Should transfer tokens from account 2 to account 3', async() => {
    var error = "";
    let token = await SecurityToken.deployed();
    let issuer = await IssuingEntity.deployed();
    try {
      await token.transfer(accounts[3], 50, {from: accounts[2]});   
    } catch(e) {
      error = e
    };
    assert.equal(
      error,
      "",
      error
    );
    let x = await token.balanceOf(accounts[2]);
    assert.equal(x.valueOf(), 0, "Sender balance is wrong.");
    x = await token.balanceOf(accounts[3]);
    assert.equal(x.valueOf(), 500, "Receiver balance is wrong.");
    x = await issuer.totalInvestors();
    assert.equal(x.valueOf(), 1, "Investor count is wrong.");
    x = await issuer.getCountryInvestorCount(1,0);
    assert.equal(x.valueOf(), 1, "Country investor count is wrong.");
    x = await issuer.getCountryInvestorCount(1,2);
    assert.equal(x.valueOf(), 1, "Country investor rating count is wrong.");
    x = await issuer.getCountryInvestorCount(1,1);
    assert.equal(x.valueOf(), 0, "Country investor rating count is wrong.");
  });

  it('Should transfer tokens from account 3 to account 2', async() => {
    var error = "";
    let token = await SecurityToken.deployed();
    let issuer = await IssuingEntity.deployed();
    try {
      await token.transfer(accounts[2], 500, {from: accounts[3]});   
    } catch(e) {
      error = e
    };
    assert.equal(
      error,
      "",
      error
    );
    let x = await token.balanceOf(accounts[2]);
    assert.equal(x.valueOf(), 500, "Sender balance is wrong.");
    x = await token.balanceOf(accounts[3]);
    assert.equal(x.valueOf(), 0, "Receiver balance is wrong.");
    x = await issuer.totalInvestors();
    assert.equal(x.valueOf(), 1, "Investor count is wrong.");
    x = await issuer.getCountryInvestorCount(1,0);
    assert.equal(x.valueOf(), 1, "Country investor count is wrong.");
    x = await issuer.getCountryInvestorCount(1,2);
    assert.equal(x.valueOf(), 0, "Country investor rating count is wrong.");
    x = await issuer.getCountryInvestorCount(1,1);
    assert.equal(x.valueOf(), 1, "Country investor rating count is wrong.");
  });


  
});