pragma solidity ^0.4.24;

import "./open-zeppelin/SafeMath.sol";
import "./SecurityToken.sol";
import "./STBase.sol";


/// @title Issuing Entity
contract IssuingEntity is STBase {

  using SafeMath64 for uint64;
  using SafeMath for uint256;

  /*
    Each country will have discrete limits for each investor type.
    minRating corresponds to investor accreditation levels:
      1 - unaccredited
      2 - accredited
      3 - qualified
  */
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

  event NewDocumentHash(string document, bytes32 hash);

  modifier onlyToken() {
    require (tokens[msg.sender]);
    _;
  }

  /// @notice Issuing entity constructor
  /// @param _registrar Address of the registrar
  constructor(address _registrar) public {
    registrar = KYCRegistrar(_registrar);
    issuerID = registrar.getId(msg.sender);
    require (registrar.getType(issuerID) == 2);
  }

  /// @notice Fetch count of all investors, regardless of rating
  /// @return integer
  function totalInvestors() public view returns (uint64) {
    return investorCount[0];
  }

  /// @notice Fetch limit of all investors, regardless of rating
  /// @return integer
  function totalInvestorLimit() public view returns (uint64) {
    return investorLimit[0];
  }

  /// @notice Fetch balance of issuer
  /// @param _id Account to query
  /// @return integer
  function balanceOf(bytes32 _id) public view returns (uint256) {
    return accounts[_id].balance;
  }

  /// @notice Fetch count of investors by country and rating
  /// @param _country Country to query
  /// @param _rating Rating to query
  /// @return integer
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

  /// @notice Fetch limit of investors by country and rating
  /// @param _country Country to query
  /// @param _rating Rating to query
  /// @return integer
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

  /// @notice Fetch count and limit of investors by country and rating
  /// in one call to preserve gas
  /// @param _country Country to query
  /// @param _rating Rating to query
  /// @return integer
  function getCountryInfo(
    uint16 _country,
    uint8 _rating
  )
    public
    view
    returns (uint64 _count, uint64 _limit)
  {
    return (countries[_country].count[_rating], countries[_country].limit[_rating]);
  }

  /// @notice Set investor limits
  /// @param _limits Array of limits per rating
  function setInvestorLimits(uint64[] _limits) public onlyIssuer {
    for (uint8 i = 0; i < _limits.length; i++) {
      investorLimit[i] = _limits[i];
    }
  }

  /// @notice Initialize a country so it can accept investors
  /// @param _country Country to create
  /// @param _minRating Minimum rating necessary to participate from this country
  /// @param _limit Number of investors allowed overall from this country
  function setCountry(uint16 _country, uint8 _minRating, uint64 _limit) public onlyIssuer {
    require (_minRating != 0);
    Country storage c = countries[_country];
    c.allowed = true;
    c.minRating = _minRating;
    c.limit[0] = _limit;
  }

  /// @notice Block a country from all transactions
  /// @param _country Country to modify
  function blockCountry(uint16 _country) public onlyIssuer {
    countries[_country].allowed = false;
  }

  /// @notice Set country investor limits after creation
  /// @param _country Country to modify
  /// @param _ratings Ratings to modify
  /// @param _limits New limits
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

  /// @notice Check if a transfer is possible at the issuing entity level
  /// @param _token Token being transferred
  /// @param _from Sender
  /// @param _to Recipient
  /// @param _value Amount being transferred
  /// @return boolean
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
    require (_idTo != issuerID);
    require (registrar.isPermitted(issuerID));
    require (registrar.isPermitted(_idFrom));
    require (registrar.isPermitted(_idTo));
    require (!accounts[_idFrom].restricted);
    require (!accounts[_idTo].restricted);
    if (_idFrom != _idTo) {
      /* Exchange to exchange transfers are not permitted */
      require (_typeFrom != 3 || _typeTo != 3);
      Country storage c = countries[_countryTo];
      require (c.allowed);
      if (_typeTo == 1) {
        uint8 _ratingTo = registrar.getRating(_idTo);
        require (_ratingTo >= c.minRating);
        /* If the receiving investor currently has a 0 balance, we must make sure a
          slot is available for allocation
        */
        if (accounts[_idTo].balance == 0) {
          /*
            If the sender is an investor and still retains a balance, a new slot
            must be available
          */
          if (_typeFrom != 1 || accounts[_idFrom].balance > _value) {
            require (investorLimit[0] == 0 || investorCount[0] < investorLimit[0]);
          }
          /*
            If the investors are of different ratings, make sure a slot is available in the
            receiver's rating in the overall count
          */
          if (registrar.getRating(_idFrom) != _ratingTo || accounts[_idFrom].balance > _value) {
            require (investorLimit[_ratingTo] == 0 || investorCount[_ratingTo] < investorLimit[_ratingTo]);
          }
          /*
            If the investors are from different countries, make sure a slot is available
            in the overall country limit
          */
          if (_countryFrom != _countryTo || accounts[_idFrom].balance > _value) {
            require (c.limit[0] == 0 || c.count[0] < c.limit[0]);
          }
          /*
            If the investors don't match in country or rating, make sure a slot is available
            in both the specific country and rating for the receiver
          */
          if (_countryFrom != _countryTo || registrar.getRating(_idFrom) != _ratingTo || accounts[_idFrom].balance > _value) {
            require (c.limit[_ratingTo] == 0 || c.count[_ratingTo] < c.limit[_ratingTo]);
          }
        }
      }
    }
    for (uint256 i = 0; i < modules.length; i++) {
      if (address(modules[i].module) != 0 && modules[i].checkTransfer) {
        require(IssuerModule(modules[i].module).checkTransfer(_token, _from, _to, _value));
      }
    }
    return true;
  }

  /// @notice Transfer tokens through the issuing entity level
  /// @param _token Token being transferred
  /// @param _from Sender
  /// @param _to Recipient
  /// @param _value Amount being transferred
  /// @return boolean
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
    _setBalance(_idFrom, accounts[_idFrom].balance.sub(_value));
    _setBalance(_idTo, accounts[_idTo].balance.add(_value));
    for (uint256 i = 0; i < modules.length; i++) {
      if (address(modules[i].module) != 0 && modules[i].transferTokens) {
        require (IssuerModule(modules[i].module).transferTokens(_token, _from, _to, _value));
      }
    }
    return true;
  }

  /// @notice Affect a direct balance change (burn/mint) at the issuing entity level
  /// @param _token Token being changed
  /// @param _owner Token owner
  /// @param _old Old balance
  /// @param _new New balance
  /// @return boolean
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

  /// @notice Directly set a balance at the issuing entity level
  /// @param _id Account to modify
  /// @param _value New balance
  /// @return boolean
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

  /// @notice Issue a new token
  /// @param string _name Name of the token
  /// @param _symbol Unique ticker symbol
  /// @param _totalSupply Total supply
  /// @return Address of created token
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

  /// @notice Set document hash
  /// @param _documentId Document ID being hashed
  /// @param _hash Hash of the document
  function setDocumentHash(string _documentId, bytes32 _hash) public onlyIssuer {
    require (documentHashes[_documentId] == 0);
    documentHashes[_documentId] = _hash;
    emit NewDocumentHash(_documentId, _hash);
  }

  /// @notice Fetch document hash
  /// @param _documentId Document ID to fetch
  /// @return string
  function getDocumentHash(string _documentId) public view returns (bytes32) {
    return documentHashes[_documentId];
  }

  /// @notice Determines if a module active on this issuing entity
  /// @param address Deployed module address
  /// @return boolean
  function isActiveModule(address _module) public view returns (bool) {
    return activeModules[_module];
  }
}
