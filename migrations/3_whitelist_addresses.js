const KYCRegistrar = artifacts.require("KYCRegistrar");

module.exports = function(deployer, network, accounts) {
  var kyc;
  deployer.then(() => {
    return KYCRegistrar.deployed();
  }).then((i) => {
    kyc = i;
    console.log("Whitelisting accounts (1/8) - Country 1, Rating 1...");
    return kyc.addInvestor("investor1", 1, 0, 1, 9999999999,
                           [accounts[2]], {from: accounts[0]});
  }).then(() => {
    console.log("Whitelisting accounts (2/8) - Country 1, Rating 2...");
    return kyc.addInvestor("investor2", 1, 0, 2, 9999999999,
                           [accounts[3]], {from: accounts[0]});
  }).then(() => {
    console.log("Whitelisting accounts (3/8) - Country 2, Rating 1...");
    return kyc.addInvestor("investor3", 2, 0, 1, 9999999999,
                           [accounts[4]], {from: accounts[0]});
  }).then(() => {
    console.log("Whitelisting accounts (4/8) - Country 2, Rating 2...");
    return kyc.addInvestor("investor4", 2, 0, 2, 9999999999,
                           [accounts[5]], {from: accounts[0]});
  }).then(() => {
    console.log("Whitelisting accounts (5/8) - Country 3, Rating 1...");
    return kyc.addInvestor("investor5", 3, 0, 1, 9999999999,
                           [accounts[6]], {from: accounts[0]});
  }).then(() => {
    console.log("Whitelisting accounts (6/8) - Country 3, Rating 2...");
    return kyc.addInvestor("investor6", 3, 0, 2, 9999999999,
                           [accounts[7]], {from: accounts[0]});
  }).then(() => {
    console.log("Whitelisting accounts (7/8) - Country 1, Rating 1 (expired)...");
    var epoch = Math.floor((new Date).getTime()/1000)+60;
    return kyc.addInvestor("investor7", 1, 0, 1, epoch,
                           [accounts[8]], {from: accounts[0]});
  }).then(() => {
    console.log("Whitelisting accounts (8/8) - Country 3, Rating 2...");
    return kyc.addInvestor("investor8", 3, 0, 2, 9999999999,
                           [accounts[9]], {from: accounts[0]});
  }).then(() => {
    console.log("Restricting account 8...");
    return kyc.setRestricted("investor8", true, {from: accounts[0]});
  });
};
