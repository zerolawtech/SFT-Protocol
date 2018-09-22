pragma solidity ^0.4.24;

import "../../open-zeppelin/safemath.sol";

import "../Base.sol";


contract ExchangeReserve is IssuerModuleBase {

  using SafeMath64 for uint64;

  struct Country {
    mapping (uint8 => uint64) reserved;
    mapping (uint8 => uint64) max;
    mapping (bytes32 => Exchange) exchanges;
  }

  struct Exchange {
    bool approved;
    mapping (uint8 => uint64) reserved;
    mapping (uint8 => uint64) max;
  }
  
  mapping (bytes32 => bool) approved;
  mapping (uint16 => Country) public countries;

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
    bytes32 _idFrom = registrar.idMap(_from);
    bytes32 _idTo = registrar.idMap(_to);
    uint8 _typeFrom = registrar.getType(_idFrom);
    uint8 _typeTo = registrar.getType(_idTo);
    if (_typeFrom != 3 && _typeTo != 3) return true;
    if (_typeFrom == 3) {
      require (approved[_idFrom]);
      uint16 _country = registrar.getCountry(_idTo);
      uint8 _rating = registrar.getRating(_idTo);
      if (issuer.getCountryInvestorLimit(_country, _rating) > 0) {
        require (countries[_country].exchanges[_idFrom].reserved[_rating] > 0);
      }
      if (issuer.getCountryInvestorLimit(_country, 0) > 0) {
        require (countries[_country].exchanges[_idFrom].reserved[0] > 0);
      }
    }
    if (_typeTo == 3) {
      require (approved[_idTo]);
    }

  }

  function balanceChanged(
    address, 
    address _owner, 
    uint256 _old, 
    uint256 _new
  )
    external 
    returns (bool)
  {
    bytes32 _id = registrar.idMap(_owner);
    uint8 _type = registrar.getType(_id);
    if (_type != 3) return true;

  }


}


contract IssuingEntityOld is STBase {

  
  
  function checkTransfer(
    bytes32 _idFrom,
    bytes32 _idTo,
    uint256 _value
  )
    public
    view
    returns (bool)
  {
    require (_idTo != issuerID);
    require (!registrar.isRestricted(issuerID));
    require (!registrar.isRestricted(_idFrom));
    require (!registrar.isRestricted(_idTo));
    require (!accounts[_idFrom].restricted);
    require (!accounts[_idTo].restricted);
    if (_idFrom == _idTo || _value == 0) return true;
    uint8 _typeFrom = registrar.getType(_idFrom);
    uint8 _typeTo = registrar.getType(_idTo);
    require (_typeFrom != 3 || _typeTo != 3);
    Country storage c = countries[registrar.getCountry(_idTo)];
    require (c.allowed);
    if (_typeTo == 1) {
      if (c.requiresAccreditation) {
        require (registrar.isAccreditted(_idTo));
      } else {
        require (registrar.isKYC(_idTo));
      }
      if (accounts[_idTo].balance == 0) {
        require (c.tLimit == 0 || c.aCount.add(c.aLimit).add(c.nCount).add(c.nLimit) < c.tLimit);
        require (totalInvestorLimit == 0 || totalInvestors() < totalInvestorLimit);
        if (registrar.isAccreditted(_idTo)) {
          require (c.aLimit == 0 || c.aCount.add(c.aReserved) < c.aLimit);
          require (accredittedInvestorLimit == 0 || accredittedInvestors < accredittedInvestorLimit);
        } else {
          require (c.nLimit == 0 || c.nCount.add(c.nReserved) < c.nLimit);
          require (nonAccredittedInvestorLimit == 0 || nonAccredittedInvestors < nonAccredittedInvestorLimit);
        }
      }
    } else if (_typeTo == 3) {
      require (exchangeApproval[_idTo]);
      if (c.aLimit > 0 || c.nLimit > 0 || c.tLimit > 0) {
        require (c.exchanges[_idTo].approved);
      }
    }
    if (_typeFrom == 3) {
      require (exchangeApproval[_idFrom]);
      Exchange storage e = c.exchanges[_idFrom];
      if (c.aLimit > 0 || c.nLimit > 0 || c.tLimit > 0) {
        require (e.approved);
        if (accounts[_idTo].balance == 0) {
          if (c.tLimit > 0) {
            require (e.tReserved > 0);
          }
          if (registrar.isAccreditted(_idTo)) {
            if (c.aLimit > 0) {
              require (e.aReserved > 0);
            }
          } else {
            if (c.nLimit > 0) {
              require (e.nReserved > 0);
            }
          }
        }
      }
    }
    return true;
  }
  
  function transferOwnership(address _from, address _to, uint256 _value) external onlyUnlocked returns (bool) {
    bytes32 _idFrom = registrar.idMap(_from);
    bytes32 _idTo = registrar.idMap(_to); 
    if (_idFrom == _idTo || _value == 0) return true;
    uint8 _typeFrom = registrar.getType(_idFrom);
    uint8 _typeTo = registrar.getType(_idTo);
    if (accounts[_idTo].balance == 0 && _typeTo == 1) {
      Country storage c = countries[registrar.getCountry(_idTo)];
      if (registrar.isAccreditted(_idTo)) {
        c.aCount = c.aCount.add(1);
        accredittedInvestors = accredittedInvestors.add(1);
      } else {
        c.nCount = c.nCount.add(1);
        nonAccredittedInvestors = nonAccredittedInvestors.add(1);
      } 
    } else if (_typeTo == 3) {
      c = countries[registrar.getCountry(_idFrom)];
      Exchange storage e = c.exchanges[_idTo];
      if (c.aLimit > 0 || c.nLimit > 0 || c.tLimit > 0) {
        if (_value == accounts[_idFrom].balance) {
          if (c.tLimit > 0) {
            e.tReserved = e.tReserved.add(1);
          }
          if (registrar.isAccreditted(_idFrom)) {
            if (c.aLimit > 0) {
              e.aReserved = e.aReserved.add(1);
            }
          } else {
            if (c.nLimit > 0) {
              e.nReserved = e.nReserved.add(1);
            }
          }
        }
      }
    }
    if (_value == accounts[_idFrom].balance && _typeFrom == 1) {
      c = countries[registrar.getCountry(_idFrom)];
      if (registrar.isAccreditted(_idFrom)) {
        c.aCount = c.aCount.sub(1);
        accredittedInvestors = accredittedInvestors.sub(1);
      } else {
        c.nCount = c.nCount.sub(1);
        nonAccredittedInvestors = nonAccredittedInvestors.sub(1);
      }
    } else if (_typeFrom == 3) {
      require (exchangeApproval[_idFrom]);
      c = countries[registrar.getCountry(_idTo)];
      e = c.exchanges[_idFrom];
      if (c.aLimit > 0 || c.nLimit > 0 || c.tLimit > 0) {
        require (e.approved);
        if (accounts[_idTo].balance == 0) {
          if (c.tLimit > 0) {
            e.tReserved = e.tReserved.sub(1);
          }
          if (registrar.isAccreditted(_idTo)) {
            if (c.aLimit > 0) {
              e.aReserved = e.aReserved.sub(1);
            }  
          } else {
            if (c.nLimit > 0) {
              e.nReserved = e.nReserved.sub(1);
            } 
          }
        }
      }
    }
    accounts[_idFrom].balance = accounts[_idFrom].balance.sub(_value);
    accounts[_idTo].balance = accounts[_idTo].balance.add(_value);
    emit TransferOwnership(_idFrom, _idTo, _value);
  }
  
  function issueNewToken(string _name, string _symbol, uint256 _totalSupply) public onlyIssuer returns (address) {
    accounts[issuerID].balance = accounts[issuerID].balance.add(_totalSupply);
    tokens.push(new SecurityToken(_name, _symbol, _totalSupply));
    return tokens[tokens.length.sub(1)];
  }
  
  
  function setCountrieRestrictions(uint16[] _countries, bool _allowed, bool _requiresAccreditation) public onlyIssuer {
    for (uint256 i = 0; i < _countries.length; i++) {
      countries[_countries[i]].allowed = _allowed;
      countries[_countries[i]].requiresAccreditation = _requiresAccreditation;
    }
  }
  
  function setCountryLimits(
    uint16 _country,
    uint64 _aLimit,
    uint64 _nLimit,
    uint64 _tLimit,
    uint64 _aReserved,
    uint64 _nReserved,
    uint64 _tReserved
  )
    public
    onlyIssuer
    returns (bool)
  {
    Country storage c = countries[_country];
    c.aLimit = _aLimit;
    c.nLimit = _nLimit;
    c.tLimit = _tLimit;
    c.aMaxReserve = _aReserved;
    c.nMaxReserve = _nReserved;
    c.tMaxReserve = _tReserved;
    return true;
  }
  
  function setExchangeCountryLimits (
    uint16 _country,
    bytes32 _exchange,
    bool _approved,
    uint64 _aLimit,
    uint64 _nLimit,
    uint64 _tLimit
  )
    public
    onlyIssuer
  {
    Country storage c = countries[_country];
    Exchange storage e = c.exchanges[_exchange];
    e.approved = _approved;
    e.aLimit = _aLimit;
    e.nLimit = _nLimit;
    e.tLimit = _tLimit;
  }
  
  function _min(uint64 a, uint64 b) internal pure returns (uint64) {
    if (a <= b) return a;
    return b;
  }

  function reserveExchangeSlots(uint16 _country) public returns (uint64, uint64, uint64) {
    bytes32 _id = registrar.idMap(msg.sender);
    require (exchangeApproval[_id]);
    Country storage c = countries[_country];
    Exchange storage e = c.exchanges[_id];
    require (e.approved);
    if (c.aLimit > 0 && e.aReserved < e.aLimit && c.aReserved < c.aMaxReserve) {
      uint64 _avail = _min(c.aLimit.sub(c.aCount).sub(c.aReserved), c.aMaxReserve.sub(c.aReserved));
      if (_avail > e.aReserved) {
        uint64 _inc = _min(_avail, e.aLimit).sub(e.aReserved);
        e.aReserved = e.aReserved.add(_inc);
        c.aReserved = c.aReserved.add(_inc); 
      }
    }
    
    if (c.nLimit > 0 && e.nReserved < e.nLimit && c.nReserved < c.nMaxReserve) {
      _avail = _min(c.nLimit.sub(c.nCount).sub(c.nReserved), c.nMaxReserve.sub(c.nReserved));
      if (_avail > e.nReserved) {
        _inc = _min(_avail, e.nLimit).sub(e.nReserved);
        e.nReserved = e.nReserved.add(_inc);
        c.nReserved = c.nReserved.add(_inc); 
      }
    }
    
    if (c.tLimit > 0 && e.tReserved < e.tLimit && c.tReserved < c.tMaxReserve) {
      _avail = _min(c.tLimit.sub(c.aCount).sub(c.nCount).sub(c.tReserved), c.tMaxReserve.sub(c.tReserved));
      if (_avail > e.tReserved) {
        _inc = _min(_avail, e.tLimit).sub(e.tReserved);
        e.tReserved = e.tReserved.add(_inc);
        c.tReserved = c.tReserved.add(_inc); 
      }
    }
    return (e.aReserved, e.nReserved, e.tReserved);    
  }
  
  function releaseExchangeSlots(uint16 _country) public returns (bool) {
    bytes32 _id = registrar.idMap(msg.sender);
    require (exchangeApproval[_id]);
    return _releaseExchange(_id, _country);
  }

  function issuerReleaseExchangeSlots(bytes32 _id, uint16 _country) public onlyIssuer returns (bool) {
    return _releaseExchange(_id, _country);
  }

  function _releaseExchange(bytes32 _id, uint16 _country) internal returns (bool) {
    Country storage c = countries[_country];
    Exchange storage e = c.exchanges[_id];
    if (e.aReserved > 0) {
      c.aReserved = c.aReserved.sub(e.aReserved);
      e.aReserved = 0;
    }
    if (e.nReserved > 0) {
      c.nReserved = c.nReserved.sub(e.nReserved);
      e.nReserved = 0;
    }
    if (e.tReserved > 0) {
      c.tReserved = c.tReserved.sub(e.tReserved);
      e.tReserved = 0;
    }
    return true;
  }
  
  function setDocumentHash(string _document, bytes32 _hash) public onlyIssuer {
    require (documentHashes[_document] == 0);
    documentHashes[_document] = _hash;
    emit NewDocumentHash(_document, _hash);
  }
  
}