const IssuingEntity = artifacts.require("IssuingEntity");
const SecurityToken = artifacts.require("SecurityToken");
const KYCRegistrar = artifacts.require("KYCRegistrar");
const MintBurn = artifacts.require("MintBurn");


var issuer, registrar, token, mod;

contract('SecurityToken', async (accounts) => {
  
  it('Should add registrar to IssuingEntity', async() => {
    var error = "";
    issuer = await IssuingEntity.deployed();
    registrar = await KYCRegistrar.deployed();
    token = await SecurityToken.deployed();
    try {
      await issuer.addRegistrar(registrar.address, {from: accounts[1]});   
    } catch(e) {
      error = e;
    };
    assert.equal(error, "", error);
  });
  
  it('Should deploy and attach MintBurn', async() => {
    mod = await MintBurn.new(issuer.address, {from: accounts[1]});
    await issuer.attachModule(issuer.address, mod.address, {from: accounts[1]});
  });

  it('Should burn some tokens', async() => {
    await mod.burn(token.address, 500000, {from: accounts[1]});
    result = await token.balanceOf(issuer.address);
    assert.equal(result.valueOf(), 500000, "burning failed");
    result = await issuer.balanceOf(await issuer.issuerID());
    assert.equal(result.valueOf(), 500000, "burning failed");
  });
  
  it('Should mint some tokens', async() => {
    await mod.mint(token.address, 1500000, {from: accounts[1]});
    let result = await token.balanceOf(issuer.address);
    assert.equal(result.valueOf(), 2000000, "minting failed");
    result = await issuer.balanceOf(await issuer.issuerID());
    assert.equal(result.valueOf(), 2000000, "minting failed");
  });

  it('Should mint some more tokens', async() => {
    await mod.mint(token.address, 1000000, {from: accounts[1]});
    let result = await token.balanceOf(issuer.address);
    assert.equal(result.valueOf(), 3000000, "minting failed");
    result = await issuer.balanceOf(await issuer.issuerID());
    assert.equal(result.valueOf(), 3000000, "minting failed");
  });

});