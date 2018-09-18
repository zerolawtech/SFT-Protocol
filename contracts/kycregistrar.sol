pragma solidity ^0.4.24;

import "./open-zeppelin/safemath.sol";

contract InvestorRegistrar {

  using SafeMath for uint256;

  address owner;

  struct Investor {
    uint40 accreditationExpires;
    uint40 kycExpires;
  }
  
  struct Entity {
    uint8 type_;
    bool restricted;
    uint16 country;
  }
  
  mapping (bytes32 => Entity) registry;

  mapping (address => bytes32) public idMap;
  mapping (bytes32 => Investor) investorData;
  
  modifier onlyOwner () {
    require (msg.sender == owner);
    _;
  }

  constructor () public {
    owner = msg.sender;
  }

  function addInvestor(
    bytes32 _id,
    uint16 _country,
    uint40 _accreditation,
    uint40 _kyc
   )
    public
    onlyOwner
  {
    _addEntity(_id, 1, _country);
    investorData[_id].accreditationExpires = _accreditation;
    investorData[_id].kycExpires = _kyc; 
  }
  
  function addIssuer(bytes32 _id, uint16 _country) public onlyOwner {
    _addEntity(_id, 2, _country);
  }
  
  function addExchange(bytes32 _id, uint16 _country) public onlyOwner {
    _addEntity(_id, 3, _country);
  }
  
  function _addEntity(bytes32 _id, uint8 _type, uint16 _country) internal {
    Entity storage e = registry[_id];
    require (e.type_ == 0);
    e.type_ = _type;
    e.country = _country;
  }
  
  function modifyRestricted (bytes32 _id, bool _restricted)  public onlyOwner {
    require (registry[_id].type_ != 0);
    registry[_id].restricted = _restricted;
  }

  function modifyAccreditation (bytes32 _id, uint40 _accreditation) public onlyOwner {
    require (registry[_id].type_ == 1);
    investorData[_id].accreditationExpires = _accreditation;
  }
  
  function modifyKYC (bytes32 _id, uint40 _kycExpires) public onlyOwner {
    require (registry[_id].type_ == 1);
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
    return sha256(abi.encodePacked(_fullName, _ddmmyyyy, _taxID));
  }

  function isRestricted (bytes32 _id) public view returns (bool) {
    return (registry[_id].type_ == 0 || registry[_id].restricted);
  }

  function isKYC (bytes32 _id) public view returns (bool) {
    if (registry[_id].type_ != 1 || registry[_id].restricted || investorData[_id].kycExpires < now) {
      return false;
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
    return registry[_id].country;
  }
  
  function getType (bytes32 _id) public view returns (uint8) {
    return registry[_id].type_;
  }

}