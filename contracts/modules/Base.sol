pragma solidity ^0.4.24;

import "../securitytoken.sol";
import "../kycregistrar.sol";
import "../company.sol";

contract _ModuleBase {

  bytes32 public issuerID;
  InvestorRegistrar public registrar;
  
  modifier onlyIssuer () {
    require (registrar.idMap(msg.sender) == issuerID);
    require (!registrar.isRestricted(issuerID));
    _;
  }

}

contract STModuleBase is _ModuleBase {

  SecurityToken public token;

  constructor(address _token) public {
    token = SecurityToken(_token);
    issuerID = token.issuerID();
    registrar = InvestorRegistrar(token.registrar());
  }
  
  modifier onlyParent() {
    require (msg.sender == address(token) || msg.sender == token.issuer());
    _;
  }

  function owner() public view returns (address) {
    return address(token);
  }

}

contract IssuerModuleBase is _ModuleBase {

  IssuingEntity public issuer;

  constructor(address _issuer) public {
    issuer = IssuingEntity(_issuer);
    issuerID = issuer.issuerID();
    registrar = InvestorRegistrar(issuer.registrar());
  }

  modifier onlyParent() {
    require (msg.sender == address(issuer));
  }

  function owner() public view returns (address) {
    return address(issuer);
  }

}