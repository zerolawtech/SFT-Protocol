pragma solidity ^0.4.24;


import "./safemath.sol";
import "./company.sol";
import "./base.sol";

contract SecurityToken is STBase {

  using SafeMath for uint256;
  
  IssuingEntity public issuer;
  uint256 public tokenID;
  uint8 public constant decimals = 0;
  string public name;
  string public symbol;
  
  struct Dividend {
    uint256 amount;
    uint256 remaining;
    uint256 totalSupply;
    uint256 checkpoint;
    uint40 claimExpiration;
    bool expired;
    mapping (address => bool) claimed;
  }
  
  uint256[] _totalSupply;
  uint256[] tsIndex;
  
  mapping (uint16 => uint256) public countryLock;
  
  struct ExchangeBalance {
    uint256 total;
    mapping (bytes32 => uint256) exchange;
  }
  
  mapping (address => ExchangeBalance) exchangeBalances; 
  
  Dividend[] dividends;
  uint40[] cpTimes;
  mapping (address => uint256[]) balances;
  mapping (address => uint256[]) cpIndex;
  
  mapping (address => mapping (address => uint256)) allowed;
  
  event Transfer(address indexed from, address indexed to, uint tokens);
  event Approval(address indexed tokenOwner, address indexed spender, uint tokens);
  event TokenBurn(address tokenOwner, uint tokens);
  event DividendIssued(uint256 dividendID, uint256 amount);
  event DividendClaimed(uint256 dividendID, address beneficiary, uint256 amount);
  event DividendExpired(uint256 dividendID, uint256 unclaimedAmount);
  
  constructor(string _name, string _symbol, uint256 _tS) public {
    issuer = IssuingEntity(msg.sender);
    issuerID = issuer.issuerID();
    registrar = InvestorRegistrar(issuer.registrar());
    name = _name;
    symbol = _symbol;
    cpTimes.push(0);
    balances[msg.sender].push(_tS);
    cpIndex[msg.sender].push(1);
    _totalSupply.push(_tS);
    tsIndex.push(1);
  }
  
  function() public payable {
    revert();
  }
  
  function circulatingSupply() public view returns (uint256) {
    return totalSupply().sub(balanceOf(address(issuer)));
  }
  
  function treasurySupply() public view returns (uint256) {
    return balanceOf(address(issuer));
  }
  
  function totalSupply() public view returns (uint256) {
    return _totalSupply[_totalSupply.length.sub(1)];
  }
  
  function totalSupplyAt(uint256 _index) public view returns (uint256) {
    require (_index < cpTimes.length);
    for (uint256 i = 0; i < _totalSupply.length.sub(1); i++) {
      if (tsIndex[i] <= _index && tsIndex[i.add(1)] > _index) {
        return _totalSupply[i];
      }
    }
    return _totalSupply[_totalSupply.length.sub(1)];
  }
  
  function balanceOf(address _owner) public view returns (uint256) {
    if (balances[_owner].length == 0) return 0;
    return balances[_owner][balances[_owner].length.sub(1)];
  }
  
  function balanceOfAt(address _owner, uint256 _index) public view returns (uint256) {
    require (_index < cpTimes.length);
    if (balances[_owner].length == 0) return 0;
    for (uint256 i = 0; i < balances[_owner].length.sub(1); i++) {
      if (cpIndex[_owner][i] <= _index && cpIndex[_owner][i.add(1)] > _index) {
        return balances[_owner][i];
      }
    }
    return balances[_owner][balances[_owner].length.sub(1)];
  }
  
  function allowance(
    address _owner,
    address _spender
   )
    public
    view
    returns (uint256)
  {
    return allowed[_owner][_spender];
  }
  
  function checkTransferValidity(address _from, address _to, uint256 _value) public view returns (bool) {
    bytes32 _idFrom = registrar.idMap(_from);
    bytes32 _idTo = registrar.idMap(_to); 
    require (countryLock[registrar.getCountry(_idFrom)] < now);
    require (countryLock[registrar.getCountry(_idTo)] < now);
    require (issuer.checkTransferValidity(_idFrom, _idTo, _value));
    return true;
  }
  
  function transfer(address _to, uint256 _value) public onlyUnlocked returns (bool) {
    _transfer(msg.sender, _to, _value);
    return true;
  }
  
  function _transfer(address _from, address _to, uint256 _value) internal {
    if (registrar.idMap(_from) == issuerID) {
      _from = address(issuer);
    } else {
      require (checkTransferValidity(_from, _to, _value));
    }
    require (issuer.transferOwnership(_from, _to, _value));
    uint256 _balanceFrom = _getBalance(_from);
    _setBalance(_from, _balanceFrom.sub(_value));
    uint256 _balanceTo = _getBalance(_to);
    _setBalance(_to, _balanceTo.add(_value));
    emit Transfer(_from, _to, _value);
  }
  
  function _getBalance(address _addr) internal returns (uint256) {
    if (cpIndex[_addr].length == 0) {
      cpIndex[_addr].push(0);
      balances[_addr].push(0);
    }
    return balances[_addr][balances[_addr].length.sub(1)];
  }
  
  function _setBalance(address _addr, uint256 _value) internal {
    uint256 _idx = cpTimes[cpTimes.length.sub(1)] > now ? cpTimes.length.sub(1) : cpTimes.length;
    if (cpIndex[_addr][cpIndex[_addr].length.sub(1)] != _idx) {
      balances[_addr].push(_value);
      cpIndex[_addr].push(_idx);
    } else {
      balances[_addr][balances[_addr].length.sub(1)] = _value;
    }
  }
  
  function approve(address _spender, uint256 _value) public returns (bool) {
    require (_value == 0 || allowed[msg.sender][_spender] == 0);
    allowed[msg.sender][_spender] = _value;
    emit Approval(msg.sender, _spender, _value);
    return true;
  }

  function transferFrom(
    address _from,
    address _to,
    uint256 _value
  )
    public
    onlyUnlocked
    returns (bool)
  {
    if (registrar.idMap(_from) != registrar.idMap(msg.sender) && registrar.idMap(msg.sender) != issuerID) {
      allowed[_from][msg.sender] = allowed[_from][msg.sender].sub(_value);
    }
    _transfer(_from, _to, _value);
    return true;
  }
  
  function lockTransfers () public onlyIssuer {
    locked = true;
  }
  
  function unlockTransfers () public onlyIssuer {
    locked = false;
  }
  
  function addCheckpoint(uint40 _epochTime) public onlyIssuer returns (uint256) {
    if (_epochTime == 0) {
      _epochTime = uint40(now);
    }
    require (_epochTime >= now);
    require (_epochTime > cpTimes[cpTimes.length.sub(1)]);
    require (now > cpTimes[cpTimes.length.sub(1)]);
    cpTimes.push(_epochTime);
    return cpTimes.length.sub(1);
  }
  
  function modifyCheckpoint(uint40 _epochTime) public onlyIssuer returns (uint256) {
    if (_epochTime == 0) {
      _epochTime = uint40(now);
    }
    require (_epochTime >= now);
    require (cpTimes[cpTimes.length.sub(1)] > now);
    cpTimes[cpTimes.length.sub(1)] = _epochTime;
    return cpTimes.length.sub(1);
  }
  
  function getCheckpointTime(uint256 _index) public view returns (uint256 _epochTime) {
    return cpTimes[_index];
  }
  
  function issueDividend(uint256 _checkpoint, uint40 _claimExpiration) public onlyIssuer payable returns (uint256) {
    require (_claimExpiration > now);
    uint256 _cs = totalSupplyAt(_checkpoint).sub(balanceOfAt(address(issuer), _checkpoint));
    dividends.push(Dividend(msg.value, msg.value, _cs, _checkpoint, _claimExpiration, false));
    emit DividendIssued(dividends.length.sub(1), msg.value);
    return dividends.length.sub(1);
  }
  
  function claimDividend(uint256 _dividendID, address _beneficiary) public {
    if (_dividendID == 0 && dividends.length > 1) {
      _dividendID = dividends.length.sub(1);
    }
    if (_beneficiary == 0) {
      _beneficiary = msg.sender;
    }
    require (registrar.idMap(_beneficiary) != issuerID);
    Dividend storage d = dividends[_dividendID];
    require (!d.expired);
    require (!d.claimed[_beneficiary]);
    uint256 _value = balanceOfAt(_beneficiary, d.checkpoint).mul(d.amount).div(d.totalSupply);
    d.claimed[_beneficiary] = true;
    d.remaining = d.remaining.sub(_value);
    _beneficiary.transfer(_value);
    emit DividendClaimed(_dividendID, _beneficiary, _value);
  }
  
  function closeDividend(uint256 _dividendID) public onlyIssuer {
    Dividend storage d = dividends[_dividendID];
    require (d.claimExpiration <= now);
    require (d.remaining > 0);
    require (!d.expired);
    d.expired = true;
    msg.sender.transfer(d.remaining);
    emit DividendExpired(_dividendID, d.remaining);
  }
  
  function _setTotalSupply(uint256 _value) internal {
    uint256 _idx = cpTimes[cpTimes.length.sub(1)] > now ? cpTimes.length.sub(1) : cpTimes.length;
    if (tsIndex[tsIndex.length.sub(1)] != _idx) {
      _totalSupply.push(_value);
      tsIndex.push(_idx);
    } else {
      _totalSupply[_totalSupply.length.sub(1)] = _value;
    }
  }
  
  function burnTokens(uint _value) public onlyIssuer {
    address _issuer = address(issuer);
    uint256 _balance = _getBalance(_issuer);
    _setBalance(_issuer, _balance.sub(_value));
    _setTotalSupply(totalSupply().sub(_value));
    emit Transfer(_issuer, 0, _value);
    emit TokenBurn(_issuer, _value);
  }
  
  function mintTokens(uint _value) public onlyIssuer {
    address _issuer = address(issuer);
    uint256 _balance = _getBalance(_issuer);
    _setBalance(_issuer, _balance.sub(_value));
    _setTotalSupply(totalSupply().add(_value));
    emit Transfer(_issuer, 0, _value);
    emit TokenBurn(_issuer, _value);
  }
  
  function modifyCountryLock(uint16 _country, uint256 _epochTime) public onlyIssuer {
    countryLock[_country] = _epochTime;
  }
  
  function dexApprove(bytes32 _id, uint256 _value) public returns (bool) {
    require (registrar.getType(_id) == 3);
    _dexLock(_id, msg.sender, _value);
    return true;
  }
  
  function _dexLock(bytes32 _id, address _owner, uint256 _value) internal {
    ExchangeBalance storage e = exchangeBalances[_owner];
    require (balanceOf(msg.sender) > e.total.add(_value));
    e.total = e.total.add(_value);
    e.exchange[_id] = e.exchange[_id].add(_value);
  }
  
  function dexRelease(address _owner, uint256 _value) public returns (bool) {
    bytes32 _id = registrar.idMap(msg.sender);
    _dexUnlock(_id, _owner, _value);
    return true;
  }
  
  function issuerDexRelease(bytes32 _id, address _owner, uint256 _value) public onlyIssuer returns (bool) {
    _dexUnlock(_id, _owner, _value);
    return true;
  }
  
  function _dexUnlock(bytes32 _id, address _owner, uint256 _value) internal {
    ExchangeBalance storage e = exchangeBalances[_owner];
    e.exchange[_id] = e.exchange[_id].sub(_value);
    e.total = e.total.sub(_value);
  }
  
  function dexTransfer(address _from, address _to, uint256 _value, bool _locked) public onlyUnlocked returns (bool) {
    bytes32 _id = registrar.idMap(msg.sender);
    _dexUnlock(_id, _from, _value);
    _transfer(_from, _to, _value);
    if (_locked) {
      _dexLock(_id, _to, _value);
    }
    return true;
  }
  
  function dexBalanceOf(address _owner, bytes32 _exchangeID) public view returns (uint256) {
    return exchangeBalances[_owner].exchange[_exchangeID];
  }

}