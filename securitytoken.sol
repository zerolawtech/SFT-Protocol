pragma solidity ^0.4.24;


import "./safemath.sol";
import "./company.sol";


contract SecurityToken {

  using SafeMath for uint256;
  bytes32 issuerID;
  InvestorRegistrar public registrar;
  IssuingEntity public issuer;
  bool public locked;
  uint8 public constant decimals = 0;
  uint256 public totalSupply;
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
  
  modifier onlyIssuer () {
    require (registrar.idMap(msg.sender) == issuerID);
    _;
  }
  
  modifier onlyUnlocked () {
    require (!locked);
    _;
  }
  
  constructor(bytes32 _issuer, string _name, string _symbol, uint256 _totalSupply) public {
    issuerID = _issuer;
    require (registrar.entityType(issuerID) == 2);
    name = _name;
    symbol = _symbol;
    cpTimes.push(0);
    balances[owner].push(_totalSupply);
    cpIndex[owner].push(1);
    totalSupply = _totalSupply;
  }
  
  function() public payable {
    revert();
  }
  
  //function circulatingSupply() public view returns (uint256) {
  //  return totalSupply.sub(investors[issuerID].balance);
  //}
  
//  function treasurySupply() public view returns (uint256) {
//    return investors[issuerID].balance;
//  }
  
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
  
  function transfer(address _to, uint256 _value) public onlyUnlocked returns (bool) {
    _transfer(msg.sender, _to, _value);
    return true;
  }
  
  function _transfer(address _from, address _to, uint256 _value) internal {
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
    if (registrar.idMap(_from) != registrar.idMap(msg.sender)) {
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
  
  // todo from here
  
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
    dividends.push(Dividend(msg.value, msg.value, circulatingSupply(), _checkpoint, _claimExpiration, false));
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
  
  function burn(uint _value) public onlyIssuer {
    totalSupply = totalSupply.sub(_value);
    uint256 _balance = _getBalance(msg.sender);
    _setBalance(_balance.sub(_value));
    investors[issuerID].balance = investors[issuerID].sub(_value);
    emit Transfer(msg.sender, 0, _value);
    emit TokenBurn(msg.sender, _value);
  }

}