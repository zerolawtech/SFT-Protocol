pragma solidity ^0.4.24;

import "../securitytoken.sol";
import "../kycregistrar.sol";

contract ModuleBase {

  bytes32 public issuerID;
  InvestorRegistrar public registrar;
  SecurityToken public token;

  constructor(address _token) public {
    token = SecurityToken(_token);
    issuerID = token.issuerID();
    registrar = InvestorRegistrar(token.registrar());
  }

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