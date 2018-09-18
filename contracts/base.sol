pragma solidity ^0.4.24;

import "./kycregistrar.sol";

contract STBase {

  bytes32 public issuerID;
  InvestorRegistrar public registrar;
  bool public locked;

  modifier onlyIssuer () {
    require (registrar.idMap(msg.sender) == issuerID);
    require (!registrar.isRestricted(issuerID));
    _;
  }
  
  modifier onlyUnlocked () {
    require (!locked || registrar.idMap(msg.sender) == issuerID);
    _;
  }
    
  function lockTransfers () public onlyIssuer {
    locked = true;
  }

  function unlockTransfers () public onlyIssuer {
    locked = false;
  }

}