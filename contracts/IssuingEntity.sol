pragma solidity ^0.4.24;

import "./open-zeppelin/SafeMath.sol";
import "./SecurityToken.sol";
import "./STBase.sol";


/// @title Issuing Entity
contract IssuingEntity is STBase {

  using SafeMath64 for uint64;
  using SafeMath for uint256;

  /*
    Each country will have discrete limits for each investor class.
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

  /// @notice Issuing entity constructor
  /// @param _registrar Address of the registrar
  constructor(address _registrar) public {
    registrar = KYCRegistrar(_registrar);
    issuerID = registrar.getId(msg.sender);
    require (registrar.getClass(issuerID) == 2);
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

  /// @notice Fetch balance of an investor, issuer, or exchange
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
    return (
      countries[_country].count[_rating],
      countries[_country].limit[_rating]);
  }

  /// @notice Set investor limits
  /// @dev The first array entry (0) corresponds to the total investor limit,
  /// regardless of rating
  /// @param _limits Array of limits per rating
  function setInvestorLimits(uint64[] _limits) public onlyIssuer {
    for (uint8 i = 0; i < _limits.length; i++) {
      /*
        investorLimit[0] = combined sum of investorLimit[1] [2] and [3]
        investorLimit[1] = unaccredited
        investorLimit[2] = accredited
        investorLimit[3] = qualified
      */
      investorLimit[i] = _limits[i];
    }
  }

  /// @notice Initialize countries so they can accept investors
  /// @param _country[] Array of counties to add
  /// @param _minRating[] Array of minimum investor ratings necessary for each country
  /// @param _limit[] Array of maximum mumber of investors allowed from this country
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

  /// @notice Block a country from all transactions
  /// @param _country Country to modify
  function blockCountry(uint16 _country) public onlyIssuer {
    countries[_country].allowed = false;
    emit CountryBlocked(_country);
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
    (bytes32 _idFrom, uint8 _classFrom, uint16 _countryFrom) = registrar.getEntity(_from);
    (bytes32 _idTo, uint8 _classTo, uint16 _countryTo) = registrar.getEntity(_to);
    require (registrar.arePermitted(issuerID, _idFrom, _idTo));
    require (!accounts[_idFrom].restricted);
    require (!accounts[_idTo].restricted);
    if (_idFrom != _idTo) {
      /* Exchange to exchange transfers are not permitted */
      require (_classFrom != 3 || _classTo != 3);
      if (_classTo == 1) {
        Country storage c = countries[_countryTo];
        uint8 _rating = registrar.getRating(_idTo);
        require (c.allowed);
        /* If the receiving investor currently has a 0 balance, we must make sure a
          slot is available for allocation
        */
        require (_rating >= c.minRating);
        if (accounts[_idTo].balance == 0) {
          /*
            If the sender is an investor and still retains a balance, a new slot
            must be available
          */
          bool _check = _classFrom != 1 || accounts[_idFrom].balance > _value;
          if (_check) {
            require (investorLimit[0] == 0 || investorCount[0] < investorLimit[0]);
          }
          /*
            If the investors are from different countries, make sure a slot is available
            in the overall country limit
          */
          if (_check || _countryFrom != _countryTo) {
            require (c.limit[0] == 0 || c.count[0] < c.limit[0]);
          }
          if (!_check) {
            _check = registrar.getRating(_idFrom) != _rating;
          }
          /*
            If the investors are of different ratings, make sure a slot is available in the
            receiver's rating in the overall count
          */
          if (_check) {
            require (
              investorLimit[_rating] == 0 ||
              investorCount[_rating] < investorLimit[_rating]
            );
          }
          /*
            If the investors don't match in country or rating, make sure a slot is available
            in both the specific country and rating for the receiver
          */
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
    uint8 _class = registrar.getClass(_id);
    /* If this sets an investor account balance > 0, take an available slot */
    if (a.balance == 0 && _class == 1) {
      c.count[0] = c.count[0].add(1);
      c.count[_rating] = c.count[_rating].add(1);
    }
    /* If this sets an investor account balance to 0, add another available slot */
    if (_value == 0 && _class == 1) {
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

  /// @notice Determines if a module is active on this issuing entity
  /// @param address Deployed module address
  /// @return boolean
  function isActiveModule(address _module) public view returns (bool) {
    return activeModules[_module];
  }
}
