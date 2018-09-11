pragma solidity ^0.4.24;

import "./safemath.sol";

contract InvestorRegistrar {

  using SafeMath for uint256;

  address owner;

  struct Investor {
    bool registered;
    bool restricted;
    uint16 country;
    uint40 accreditationExpires;
    uint40 kycExpires;
  }
  
  struct Issuer {
    bool registered;
    bool restricted;
  }
  
  struct Exchange {
    bool registered;
    bool restricted;
  }

  mapping (address => bytes32) public idMap;
  mapping (bytes32 => uint8) public entityType;
  mapping (bytes32 => Investor) investorData;
  mapping (bytes32 => Issuer) issuerData;
  mapping (bytes32 => Exchange) exchangeData;

  modifier onlyOwner () {
    require (msg.sender == owner);
    _;
  }

  constructor () public {
    owner = msg.sender;
  }

  function addInvestor(
    bytes32 _id,
    bool _restricted,
    uint16 _country,
    uint40 _accreditation,
    uint40 _kyc
   )
    public
    onlyOwner
  {
    Investor storage i = investorData[_id];
    require (entityType[_id] == 0);
    entityType[_id] = 1;
    i.registered = true;
    i.restricted = _restricted;
    i.country = _country;
    i.accreditationExpires = _accreditation;
    i.kycExpires = _kyc; 
  }
  
  function addIssuer(bytes32 _id) public onlyOwner {
    require (entityType[_id] == 0);
    entityType[_id] = 2;
    issuerData[_id].registered = true;
  }
  
  function addExchange(bytes32 _id) public onlyOwner {
    require (entityType[_id] == 0);
    entityType[_id] = 3;
    exchangeData[_id].registered = true;
  }
  
  function modifyRestricted (bytes32 _id, bool _restricted)  public onlyOwner {
    require (entityType[_id] == 1);
    investorData[_id].restricted = _restricted;
  }

  function modifyAccreditation (bytes32 _id, uint40 _accreditation) public onlyOwner {
    require (entityType[_id] == 1);
    investorData[_id].accreditationExpires = _accreditation;
  }
  
  function modifyKYC (bytes32 _id, uint40 _kycExpires) public onlyOwner {
    require (entityType[_id] == 1);
    investorData[_id].kycExpires = _kycExpires;
  }
  
  function registerAddress (address _addr, bytes32 _id) public onlyOwner {
    require (idMap[_addr] == 0);
    idMap[_addr] = _id;
  }
  
  function unregisterAddress (address _addr) public onlyOwner {
    delete idMap[_addr];
  }

  function generateInvestorID (string _fullName, uint256 _ddmmyyyy, string _taxID) public pure returns (bytes32) {
    return sha256(_fullName, _ddmmyyyy, _taxID);
  }

  function isRestricted (bytes32 _id) public view returns (bool) {
    return !investorData[_id].registered || investorData[_id].restricted;
  }

  function isKYC (bytes32 _id) public view returns (bool) {
    Investor storage i = investorData[_id];
    if (i.registered && !i.restricted && i.kycExpires > now) {
      return true;
    }
    return false;
  }

  function isAccreditted (bytes32 _id) public view returns (bool) {
    Investor storage i = investorData[_id];
    if (i.accreditationExpires < now || !isKYC(_id)) {
      return false;
    }
    return true;
  }
  
  function getCountry (bytes32 _id) public view returns (uint16) {
    return investorData[_id].country;
  }

}