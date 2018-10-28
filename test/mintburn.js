const IssuingEntity = artifacts.require("IssuingEntity");
const SecurityToken = artifacts.require("SecurityToken");
const MintBurn = artifacts.require("MintBurn");

contract('SecurityToken', async (accounts) => {
  
  it('Should deploy MintBurn, mint and burn some tokens', async() => {
    let issuer = await IssuingEntity.deployed();
    let token = await SecurityToken.deployed();
    let mod = await MintBurn.new(issuer.address, {from: accounts[1]});
    await issuer.attachModule(issuer.address, mod.address, {from: accounts[1]});
    await mod.mint(token.address, 1000000, {from: accounts[1]});
    let result = await token.balanceOf(issuer.address);
    assert.equal(result.valueOf(), 2000000, "minting failed");
    result = await issuer.balanceOf(await issuer.issuerID());
    assert.equal(result.valueOf(), 2000000, "minting failed");
    await mod.burn(token.address, 1500000);
    result = await token.balanceOf(issuer.address);
    assert.equal(result.valueOf(), 500000, "burning failed");
    result = await issuer.balanceOf(await issuer.issuerID());
    assert.equal(result.valueOf(), 500000, "burning failed");
  });

});