pragma solidity ^0.4.24;

import "./safemath.sol";
import "./kycregistrar.sol";
import "./securitytoken.sol";


contract IssuingEntity {

  using SafeMath for uint256;
  
  bytes32 issuerID;
  InvestorRegistrar public registrar;
  bool public locked;

  uint256 public accredittedInvestors;
  uint256 public nonAccredittedInvestors;
  uint256 public accredittedInvestorLimit;
  uint256 public nonAccredittedInvestorLimit;
  uint256 public totalInvestorLimit;
  
  struct Investor {
    uint256 balance;
    bool restricted;
  }
  
  struct Country {
    bool allowed;
    bool requiresAccreditation;
    uint256 aCount;
    uint256 nCount;
    uint256 aLimit;
    uint256 nLimit;
    uint256 totalLimit;
  }

  mapping (bytes32 => Investor) investors;
  mapping (uint16 => Country) public countries;
  
  event TransferOwnership(bytes32 senderID, bytes32 receiverID, uint tokens);
  
  modifier onlyIssuer () {
    require (registrar.idMap(msg.sender) == issuerID);
    _;
  }
  
  modifier onlyUnlocked () {
    require (!locked);
    _;
  }
  
  constructor(address _registrar) public {
    registrar = InvestorRegistrar(_registrar);
    issuerID = registrar.idMap(msg.sender);
    require (registrar.entityType(issuerID) == 2);
  }
  
  function() public payable {
    revert();
  }
  
  function totalInvestors() public view returns (uint256) {
    return accredittedInvestors.add(nonAccredittedInvestors);
  }
  
  function checkTransferValidity(address _from, address _to, uint256 _value) public view returns (bool) {
    bytes32 _idFrom = registrar.idMap(_from);
    bytes32 _idTo = registrar.idMap(_to); 
    require (!registrar.isRestricted(_idFrom));
    require (!registrar.isRestricted(_idTo));
    require (!investors[_idFrom].restricted);
    require (!investors[_idTo].restricted);
    if (_idFrom == _idTo) return true;
    Country storage c = countries[registrar.getCountry(_idTo)];
    require (c.allowed);
    if (c.requiresAccreditation) {
      require (registrar.isAccreditted(_idTo));
    } else {
      require (registrar.isKYC(_idTo));
    }
    if (investors[_idTo].balance == 0 && _value > 0 && _idTo != issuerID) {
      require (c.totalLimit == 0 || c.aCount.add(c.nCount) < c.totalLimit);
      require (totalInvestorLimit == 0 || totalInvestors() < totalInvestorLimit);
      if (registrar.isAccreditted(_idTo)) {
        require (c.aLimit == 0 || c.aCount < c.aLimit);
        require (accredittedInvestorLimit == 0 || accredittedInvestors < accredittedInvestorLimit);
      } else {
        require (c.nLimit == 0 || c.nCount < c.nLimit);
        require (nonAccredittedInvestorLimit == 0 || nonAccredittedInvestors < nonAccredittedInvestorLimit);
      } 
    }
    return true;
  }
  
  function transferOwnership(address _from, address _to, uint256 _value) public returns (bool) {
    require (checkTransferValidity(_from, _to, _value));
    bytes32 _idFrom = registrar.idMap(_from);
    bytes32 _idTo = registrar.idMap(_to); 
    if (_idFrom == _idTo) return true;
    if (investors[_idTo].balance == 0 && _value > 0 && _idTo != issuerID) {
      Country storage c = countries[registrar.getCountry(_idTo)];
      if (registrar.isAccreditted(_idTo)) {
        c.aCount = c.aCount.add(1);
        accredittedInvestors = accredittedInvestors.add(1);
      } else {
        c.nCount = c.nCount.add(1);
        nonAccredittedInvestors = nonAccredittedInvestors.add(1);
      } 
    }
    if (_value == investors[_idFrom].balance && _value > 0 && _idFrom != issuerID) {
      c = countries[registrar.getCountry(_idFrom)];
      if (registrar.isAccreditted(_idFrom)) {
        c.aCount = c.aCount.sub(1);
        accredittedInvestors = accredittedInvestors.sub(1);
      } else {
        c.nCount = c.nCount.sub(1);
        nonAccredittedInvestors = nonAccredittedInvestors.sub(1);
      }
    }
    investors[_idFrom].balance = investors[_idFrom].balance.sub(_value);
    investors[_idTo].balance = investors[_idTo].balance.add(_value);
    emit TransferOwnership(_idFrom, _idTo, _value);
  }
    
  function setCountryRestrictions(
    uint16 _country,
    bool _allowed,
    bool _accredit,
    uint256 _aLimit,
    uint256 _nLimit,
    uint256 _totalLimit
  )
    public
    onlyIssuer
    returns (bool)
  {
    Country storage c = countries[_country];
    c.allowed = _allowed;
    c.requiresAccreditation = _accredit;
    c.aLimit = _aLimit;
    c.nLimit = _nLimit;
    c.totalLimit = _totalLimit;
    return true;
  }
  
  function issueNewToken(string _name, string _symbol, uint256 _totalSupply) public onlyIssuer {
    investors[issuerID].balance = investors[issuerID].balance.add(_totalSupply);
    new SecurityToken(issuerID, _name, _symbol, _totalSupply);
  }
  
}