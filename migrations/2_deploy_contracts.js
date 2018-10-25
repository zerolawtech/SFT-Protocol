const KYCRegistrar = artifacts.require("KYCRegistrar");
const IssuingEntity = artifacts.require("IssuingEntity");
const SecurityToken = artifacts.require("SecurityToken");

module.exports = function(deployer, network, accounts) {

  var kyc,issuer,token;
  deployer.deploy(
    KYCRegistrar,
    [accounts[0]],
    "authority",
    1,
    {from: accounts[0]}
  ).then(() => {
    return KYCRegistrar.deployed();
  }).then((i) => {
    kyc = i;
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
  }).then((i) => {
    token = i;
    console.log("Adding Token to IssuingEntity...");
    return issuer.addToken(
      SecurityToken.address,
      {from: accounts[1]}
    );
  }).then(() => {
    console.log("Whitelisting accounts (1/3)...");
    return kyc.addInvestor(
      "investor1",
      1,
      0,
      1,
      9999999999,
      [accounts[2]],
      {from: accounts[0]}
    );
  }).then(() => {
    console.log("Whitelisting accounts (2/3)...");
    return kyc.addInvestor(
      "investor2",
      1,
      0,
      2,
      9999999999,
      [accounts[3]],
      {from: accounts[0]}
    );
  }).then(() => {
    console.log("Whitelisting accounts (3/3)...");
    return kyc.addInvestor(
      "investor3",
      2,
      0,
      1,
      9999999999,
      [accounts[4]],
      {from: accounts[0]}
    );
  });


};
