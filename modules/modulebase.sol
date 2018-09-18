pragma solidity ^0.4.24;

import "../securitytoken.sol";
import "../kycregistrar.sol";

contract ModuleBase {

  bytes32 public issuerID;
  InvestorRegistrar public registrar;
  SecurityToken public token;

  modifier onlyIssuer () {
    require (registrar.idMap(msg.sender) == issuerID);
    require (!registrar.isRestricted(issuerID));
    _;
  }
  
  modifier onlyToken() {
    require (msg.sender == address(token));
    _;
  }

}