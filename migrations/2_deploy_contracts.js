const KYCRegistrar = artifacts.require("KYCRegistrar");
const IssuingEntity = artifacts.require("IssuingEntity");
const SecurityToken = artifacts.require("SecurityToken");

module.exports = function(deployer, network, accounts) {
  var issuer;
  console.log("Deploying KYCRegistrar...");
  deployer.deploy(
    KYCRegistrar,
    [accounts[0]],
    "authority",
    1,
    {from: accounts[0]}
  ).then(() => {
    return KYCRegistrar.deployed();
  }).then(() => {
    console.log("Deploying IssuingEntity...");
    return deployer.deploy(
      IssuingEntity,
      [accounts[1]],
      1,
      {from: accounts[1]}
    );
  }).then(() => {
    return IssuingEntity.deployed();
  }).then((i) => {
    issuer = i;
    console.log("Deploying SecurityToken...");
    return deployer.deploy(
      SecurityToken,
      IssuingEntity.address,
      "Test Security Token",
      "TST",
      1000000,
      {from: accounts[1]}
    );
  }).then(() => {
    return SecurityToken.deployed();
  }).then(() => {
    console.log("Adding Token to IssuingEntity...");
    return issuer.addToken(
      SecurityToken.address,
      {from: accounts[1]}
    );
  })
};
