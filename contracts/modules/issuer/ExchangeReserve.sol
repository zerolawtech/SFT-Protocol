pragma solidity ^0.4.24;

import "../../open-zeppelin/SafeMath.sol";
import "../STBase.sol";


contract ExchangeReserve is IssuerModuleBase {

  using SafeMath64 for uint64;

  struct Country {
    mapping (uint8 => uint64) reserved;
    mapping (uint8 => uint64) max;
    mapping (bytes32 => Exchange) exchanges;
  }

  struct Exchange {
    mapping (uint8 => uint64) reserved;
    mapping (uint8 => uint64) max;
  }

  mapping (bytes32 => bool) approved;
  mapping (uint16 => Country) countries;

  modifier onlyExchange() {
    bytes32 _id = registrar.getId(msg.sender);
    require (approved[_id]);
    _;
  }

  function getCountryReserved(
    uint16 _country,
    uint8 _rating
  )
    public
    view
    returns (uint64 _reserved, uint64 _max)
  {
    Country storage c = countries[_country];
    return (c.reserved[_rating], c.max[_rating]);
  }

  function getExchangeReserved(
    bytes32 _id,
    uint16 _country,
    uint8 _rating
  )
    public
    view
    returns (uint64 _reserved, uint64 _max)
  {
    Exchange storage e = countries[_country].exchanges[_id];
    return (e.reserved[_rating], e.max[_rating]);
  }

  function checkTransfer(
    address,
    address _from,
    address _to,
    uint256 _value
  )
    public
    view
    returns (bool)
  {
    (bytes32 _idFrom, uint8 _classFrom, uint16 _countryFrom) = registrar.getEntity(_from);
    (bytes32 _idTo, uint8 _classTo, uint16 _countryTo) = registrar.getEntity(_to);
    if (_classFrom != 3 && _classTo == 1 && issuer.balanceOf(_idTo) == 0) {
      uint8 _ratingFrom = registrar.getRating(_idFrom);
      uint8 _ratingTo = registrar.getRating(_idTo);
      bool _remains = issuer.balanceOf(_idFrom) > _value;
      if (_countryFrom != _countryTo || _classFrom != 1 || _remains) {
        (uint64 _count, uint64 _limit) = issuer.getCountryInfo(_countryTo, 0);
        if (_limit > 0) {
          require (_limit.sub(_count) > countries[_countryTo].reserved[0]);
        }
      }
      if (_countryFrom != _countryTo || _classFrom != 1 || _remains || _ratingFrom != _ratingTo) {
        (_count, _limit) = issuer.getCountryInfo(_countryTo, _ratingTo);
        if (_limit > 0) {
          require (_limit.sub(_count) > countries[_countryTo].reserved[_rating]);
        }
      }
    } else if (_classFrom == 3  && _classTo == 1) {
      require (approved[_idFrom]);
      uint8 _rating = registrar.getRating(_idTo);
      Exchange storage e = countries[_countryTo].exchanges[_idFrom];
      if (issuer.getCountryInvestorLimit(_countryTo, _rating) > 0) {
        require (e.reserved[_rating] > 0);
      }
      if (issuer.getCountryInvestorLimit(_countryTo, 0) > 0) {
        require (e.reserved[0] > 0);
      }
    } else if (_classTo == 3) {
      require (approved[_idTo]);
    }
    return true;
  }

  function transferTokens(
    address,
    address _from,
    address _to,
    uint256 _value
  )
    external
    onlyParent
    returns (bool)
  {
    (bytes32 _idFrom, uint8 _classFrom, uint16 _countryFrom) = registrar.getEntity(_from);
    (bytes32 _idTo, uint8 _classTo, uint16 _countryTo) = registrar.getEntity(_to);
    if (_classFrom != 3 && _classTo != 3) return true;
    if (_classFrom == 1 && _classTo == 3 && issuer.balanceOf(_idFrom) == 0) {
      uint8 _rating = registrar.getRating(_idFrom);
      Country storage c = countries[_countryFrom];
      Exchange storage e = c.exchanges[_idTo];
      if (issuer.getCountryInvestorLimit(_countryFrom, _rating) > 0) {
        e.reserved[_rating] = e.reserved[_rating].add(1);
        c.reserved[_rating] = c.reserved[_rating].add(1);
      }
      if (issuer.getCountryInvestorLimit(_countryFrom, 0) > 0) {
        e.reserved[0] = e.reserved[0].add(1);
        c.reserved[0] = c.reserved[0].add(1);
      }
    }
    if (_classFrom == 3 && _classTo == 1 && issuer.balanceOf(_idTo) == _value) {
      _rating = registrar.getRating(_idTo);
      c = countries[_countryTo];
      e = c.exchanges[_idTo];
      if (issuer.getCountryInvestorLimit(_countryTo, _rating) > 0) {
        e.reserved[_rating] = e.reserved[_rating].sub(1);
        c.reserved[_rating] = c.reserved[_rating].sub(1);
      }
      if (issuer.getCountryInvestorLimit(_countryTo, 0) > 0) {
        e.reserved[0] = e.reserved[0].sub(1);
        c.reserved[0] = c.reserved[0].sub(1);
      }
    }
  }

  function _min(uint64 a, uint64 b) internal pure returns (uint64) {
    if (a <= b) return a;
    return b;
  }

  function exchangeReserve(uint16 _country, uint8 _rating) public onlyExchange returns (uint64) {
    bytes32 _id = registrar.getId(msg.sender);
    Country storage c = countries[_country];
    Exchange storage e = c.exchanges[_id];
    if (c.max[_rating] > 0 && c.max[_rating] > c.reserved[_rating] && e.max[_rating] > e.reserved[_rating]) {
      (uint64 _count, uint64 _limit) = issuer.getCountryInfo(_country, _rating);
      uint64 _avail = _min(_limit.sub(_count).sub(c.reserved[_rating]), c.max[_rating].sub(c.reserved[_rating]));
      if (_avail > e.reserved[_rating]) {
        uint64 _inc = _min(_avail, e.max[_rating]).sub(e.reserved[_rating]);
        e.reserved[_rating] = e.reserved[_rating].add(_inc);
        c.reserved[_rating] = c.reserved[_rating].add(_inc);
      }
    }
    return e.reserved[0];
  }

  function exchangeRelease(
    uint16 _country,
    uint8 _rating,
    uint64 _value
  )
    public
    onlyExchange
    returns (bool)
  {
    return _releaseExchange(registrar.getId(msg.sender), _country, _rating, _value);
  }

  function exchangeReleaseMany(
    uint16[] _country,
    uint8[] _rating,
    uint64[] _value
  )
    public
    onlyExchange
    returns (bool)
  {
    require (_country.length == _rating.length && _country.length == _value.length);
    bytes32 _id = registrar.getId(msg.sender);
    for (uint256 i = 0; i < _country.length; i++) {
      _releaseExchange(_id, _country[i], _rating[i], _value[i]);
    }
    return true;
  }

  function issuerRelease(
    bytes32 _id,
    uint16 _country,
    uint8 _rating,
    uint64 _value
  )
    public
    onlyIssuer
    returns (bool)
  {
    return _releaseExchange(_id, _country, _rating, _value);
  }

  function issuerReleaseMany(
    bytes32 _id,
    uint16[] _country,
    uint8[] _rating,
    uint64[] _value
  )
    public
    onlyIssuer
    returns (bool)
  {
    require (_country.length == _rating.length && _country.length == _value.length);
    for (uint256 i = 0; i < _country.length; i++) {
      _releaseExchange(_id, _country[i], _rating[i], _value[i]);
    }
  }

  function _releaseExchange(
    bytes32 _id,
    uint16 _country,
    uint8 _rating,
    uint64 _value
  )
    internal
    returns (bool)
  {
    Country storage c = countries[_country];
    Exchange storage e = c.exchanges[_id];
    _value = _min(_value, e.reserved[_rating]);
    c.reserved[_rating] = c.reserved[_rating].sub(_value);
    e.reserved[_rating] = e.reserved[_rating].sub(_value);
    return true;
  }

}
