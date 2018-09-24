pragma solidity ^0.4.24;

import "./open-zeppelin/SafeMath.sol";
import "./SecurityToken.sol";
import "./Base.sol";


contract IssuingEntity is STBase {

  using SafeMath64 for uint64;
  using SafeMath for uint256;

  struct Country {
    bool allowed;
    uint8 minRating;
    mapping (uint8 => uint64) count;
    mapping (uint8 => uint64) limit;
  }

  struct Account {
    uint256 balance;
    bool restricted;
  }

  mapping (uint8 => uint64) investorCount;
  mapping (uint8 => uint64) investorLimit;
  mapping (uint16 => Country) countries;
  mapping (bytes32 => Account) accounts;
  mapping (address => bool) tokens;
  mapping (string => bytes32) documentHashes;

  event TransferOwnership(
    address token, 
    bytes32 from, 
    bytes32 to, 
    uint256 value
  );
  event CountryApproved(uint16 country, uint8 minRating, uint64 limit);
  event CountryBlocked(uint16 country);
  event NewDocumentHash(string document, bytes32 hash);

  modifier onlyToken() {
    require (tokens[msg.sender]);
    _;
  }

  constructor(address _registrar) public {
    registrar = KYCRegistrar(_registrar);
    issuerID = registrar.getId(msg.sender);
    require (registrar.getType(issuerID) == 2);
  }

  function totalInvestors() public view returns (uint64) {
    return investorCount[0];
  }

  function totalInvestorLimit() public view returns (uint64) {
    return investorLimit[0];
  }

  function balanceOf(bytes32 _id) public view returns (uint256) {
    return accounts[_id].balance;
  }

  function getCountryInvestorCount(
    uint16 _country, 
    uint8 _rating
  ) 
    public 
    view 
    returns (uint64) 
  {
    return countries[_country].count[_rating];
  }

  function getCountryInvestorLimit(
    uint16 _country, 
    uint8 _rating
  )
    public 
    view 
    returns (uint64) 
  {
    return countries[_country].limit[_rating];
  }

  function getCountryInfo(
    uint16 _country, 
    uint8 _rating
  )
    public 
    view 
    returns (uint64 _count, uint64 _limit) 
  {
    return (
      countries[_country].count[_rating], 
      countries[_country].limit[_rating]);
  }

  function setInvestorLimits(uint64[] _limits) public onlyIssuer {
    for (uint8 i = 0; i < _limits.length; i++) {
      investorLimit[i] = _limits[i];
    }
  }

  function setCountries(
    uint16[] _country, 
    uint8[] _minRating, 
    uint64[] _limit
  ) 
    public 
    onlyIssuer 
  {
    require (_country.length == _minRating.length);
    require (_country.length == _limit.length);
    for (uint256 i = 0; i < _country.length; i++) {
      require (_minRating[i] != 0);
      Country storage c = countries[_country[i]];
      c.allowed = true;
      c.minRating = _minRating[i];
      c.limit[0] = _limit[i];
      emit CountryApproved(_country[i], _minRating[i], _limit[i]);
    }
  }

  function blockCountry(uint16 _country) public onlyIssuer {
    countries[_country].allowed = false;
    emit CountryBlocked(_country);
  }

  function setCountryInvestorLimits(
    uint16 _country, 
    uint8[] _ratings,
    uint64[] _limits
  ) 
    public 
    onlyIssuer 
  {
    require (_ratings.length == _limits.length);
    Country storage c = countries[_country];
    require (c.allowed);
    for (uint256 i = 0; i < _ratings.length; i++) {
      require (_ratings[i] != 0);
      c.limit[_ratings[i]] = _limits[i];
    }
  }

  function checkTransfer(
    address _token,
    address _from,
    address _to,
    uint256 _value
  )
    public
    view
    returns (bool)
  {
    require (_value > 0);
    (bytes32 _idFrom, uint8 _typeFrom, uint16 _countryFrom) = registrar.getEntity(_from);
    (bytes32 _idTo, uint8 _typeTo, uint16 _countryTo) = registrar.getEntity(_to);
    require (registrar.arePermitted(issuerID, _idFrom, _idTo));
    require (!accounts[_idFrom].restricted);
    require (!accounts[_idTo].restricted);
    if (_idFrom != _idTo) {
      require (_typeFrom != 3 || _typeTo != 3);
      if (_typeTo == 1) {
        Country storage c = countries[_countryTo];
        uint8 _rating = registrar.getRating(_idTo);
        require (c.allowed);
        require (_rating >= c.minRating);
        if (accounts[_idTo].balance == 0) {
          bool _check = _typeFrom != 1 || accounts[_idFrom].balance > _value;
          if (_check) {
            require (investorLimit[0] == 0 || investorCount[0] < investorLimit[0]);
          }
          if (_check || _countryFrom != _countryTo) {
            require (c.limit[0] == 0 || c.count[0] < c.limit[0]); 
          }
          if (!_check) {
            _check = registrar.getRating(_idFrom) != _rating;
          }
          if (_check) {
            require (
              investorLimit[_rating] == 0 || 
              investorCount[_rating] < investorLimit[_rating]
            );
          }
          if (_check || _countryFrom != _countryTo) {
            require (
              c.limit[_rating] == 0 || 
              c.count[_rating] < c.limit[_rating]
            );
          }
        }
      }
    }
    _moduleCheckTransfer(_token, _from, _to, _value);
    return true;
  }

  function _moduleCheckTransfer(
    address _token,
    address _from,
    address _to,
    uint256 _value
  )
    internal
    view
  {
    for (uint256 i = 0; i < modules.length; i++) {
      if (address(modules[i].module) != 0 && modules[i].checkTransfer) {
        require(IssuerModule(modules[i].module).checkTransfer(_token, _from, _to, _value));
      }
    }
  }

  function transferTokens(
    address _token, 
    address _from, 
    address _to, 
    uint256 _value
  )
    external 
    onlyUnlocked 
    onlyToken 
    returns (bool) 
  {
    bytes32 _idFrom = registrar.getId(_from);
    bytes32 _idTo = registrar.getId(_to);
    if (_idFrom == _idTo) return true;
    _setBalance(_idFrom, accounts[_idFrom].balance.sub(_value));
    _setBalance(_idTo, accounts[_idTo].balance.add(_value));
    for (uint256 i = 0; i < modules.length; i++) {
      if (address(modules[i].module) != 0 && modules[i].transferTokens) {
        require (IssuerModule(modules[i].module).transferTokens(_token, _from, _to, _value));
      }
    }
    emit TransferOwnership(_token, _idFrom, _idTo, _value);
    return true;
  }

  function balanceChanged(
    address _token,
    address _owner, 
    uint256 _old, 
    uint256 _new
  )
    external 
    onlyUnlocked
    onlyToken
    returns (bool) 
  {
    bytes32 _id = registrar.getId(_owner);
    if (_new > _old) {
      _setBalance(_id, accounts[_id].balance.add(_new.sub(_old)));
    } else {
      _setBalance(_id, accounts[_id].balance.sub(_old.sub(_new)));
    }
    for (uint256 i = 0; i < modules.length; i++) {
      if (address(modules[i].module) != 0 && modules[i].balanceChanged) {
        require (IssuerModule(modules[i].module).balanceChanged(_token, _owner, _old, _new));
      }
    }
    return true;
  }

  function _setBalance(bytes32 _id, uint256 _value) internal {
    Account storage a = accounts[_id];
    Country storage c = countries[registrar.getCountry(_id)];
    uint8 _rating = registrar.getRating(_id);
    uint8 _type = registrar.getType(_id);
    if (a.balance == 0 && _type == 1) {
      c.count[0] = c.count[0].add(1);
      c.count[_rating] = c.count[_rating].add(1);
    }
    if (_value == 0 && _type == 1) {
      c.count[0] = c.count[0].sub(1);
      c.count[_rating] = c.count[_rating].sub(1);
    }
    a.balance = _value;
  }

  function issueNewToken(
    string _name,
    string _symbol,
    uint256 _totalSupply
  )
    public 
    onlyIssuer 
    returns (address)
  {
    accounts[issuerID].balance = accounts[issuerID].balance.add(_totalSupply);
    address _token = new SecurityToken(_name, _symbol, _totalSupply);
    tokens[_token] = true;
    return _token;
  }
  
  function setDocumentHash(string _documentId, bytes32 _hash) public onlyIssuer {
    require (documentHashes[_documentId] == 0);
    documentHashes[_documentId] = _hash;
    emit NewDocumentHash(_documentId, _hash);
  }

  function getDocumentHash(string _documentId) public view returns (bytes32) {
    return documentHashes[_documentId];
  }

  function isActiveModule(address _module) public view returns (bool) {
    return activeModules[_module];
  }

}