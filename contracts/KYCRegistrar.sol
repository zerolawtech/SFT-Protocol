pragma solidity ^0.4.24;

import "./open-zeppelin/SafeMath.sol";

contract KYCRegistrar {

  using SafeMath for uint256;

  address owner;

  struct Investor {
    uint8 rating;
    uint40 expires;
  }
  
  struct Entity {
    uint8 type_;
    bool restricted;
    uint16 country;
  }
  
  mapping (bytes32 => Entity) registry;
  mapping (address => bytes32) idMap;
  mapping (bytes32 => Investor) investorData;

  event NewInvestor (bytes32 id, uint16 country, uint8 rating, uint40 expires);
  event NewIssuer (bytes32 id, uint16 country);
  event NewExchange (bytes32 id, uint16 country);
  event EntityRestriction (bytes32 id, uint8 type_, bool restricted);
  event NewRegisteredAddress(bytes32 id, uint8 type_, address addr);
  event UnregisteredAddress(bytes32 id, uint8 type_, address addr);
  
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
    uint8 _rating,
    uint40 _expires
   )
    public
    onlyOwner
  {
    require (_rating > 0);
    _addEntity(_id, 1, _country);
    investorData[_id].rating = _rating;
    investorData[_id].expires = _expires;
    emit NewInvestor(_id, _country, _rating, _expires);
  }
  
  function addIssuer(bytes32 _id, uint16 _country) public onlyOwner {
    _addEntity(_id, 2, _country);
    emit NewIssuer(_id, _country);
  }
  
  function addExchange(bytes32 _id, uint16 _country) public onlyOwner {
    _addEntity(_id, 3, _country);
    emit NewExchange(_id, _country);
  }
  
  function _addEntity(bytes32 _id, uint8 _type, uint16 _country) internal {
    Entity storage e = registry[_id];
    require (e.type_ == 0);
    e.type_ = _type;
    e.country = _country;
  }
  
  function setRestricted (bytes32 _id, bool _restricted)  public onlyOwner {
    require (registry[_id].type_ != 0);
    registry[_id].restricted = _restricted;
    emit EntityRestriction(_id, registry[_id].type_, _restricted);
  }

  function registerAddress (address _addr, bytes32 _id) public onlyOwner {
    require (idMap[_addr] == 0);
    require (registry[_id].type_ != 0);
    idMap[_addr] = _id;
    emit NewRegisteredAddress(_id, registry[_id].type_, _addr);
  }
  
  function unregisterAddress (address _addr) public onlyOwner {
    require (idMap[_addr] != 0);
    emit UnregisteredAddress(idMap[_addr], registry[idMap[_addr]].type_, _addr);
    delete idMap[_addr];
  }

  function generateInvestorID (
    string _fullName, 
    uint256 _ddmmyyyy, 
    string _taxID
  )
    public 
    pure 
    returns (bytes32) 
  {
    return sha256(abi.encodePacked(_fullName, _ddmmyyyy, _taxID));
  }

  function isRestricted (bytes32 _id) public view returns (bool) {
    return (registry[_id].type_ == 0 || registry[_id].restricted);
  }

  function getRating (bytes32 _id) public view returns (uint8) {
    Investor storage i = investorData[_id];
    require (i.expires >= now);
    require (i.rating > 0);
    return investorData[_id].rating;
  }

  function getId(address _addr) public view returns (bytes32) {
    return idMap[_addr];
  }

  function getType (bytes32 _id) public view returns (uint8) {
    return registry[_id].type_;
  }


  function getCountry (bytes32 _id) public view returns (uint16) {
    return registry[_id].country;
  }
  

  function getEntity(
    address _addr
  )
    public 
    view 
    returns (bytes32 _id, uint8 _type, uint16 _country) 
  {
    _id = idMap[_addr];
    return (_id, registry[_id].type_, registry[_id].country);
  }

}