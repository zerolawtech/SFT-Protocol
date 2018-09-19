pragma solidity ^0.4.24;


import "./open-zeppelin/safemath.sol";
import "./company.sol";
import "./base.sol";
import "./modules/CheckpointBase.sol";

contract SecurityTokenOld is STBase {

  using SafeMath for uint256;
  
  IssuingEntity public issuer;
  uint8 public constant decimals = 0;
  string public name;
  string public symbol;
  uint256 public totalSupply;
  CheckpointModule[] checkpoints;
  
  mapping (uint16 => uint256) public countryLock;
  
  struct ExchangeBalance {
    uint256 total;
    mapping (bytes32 => uint256) exchange;
  }
  
  mapping (address => ExchangeBalance) exchangeBalances; 
  mapping (address => uint256) balances; 
  mapping (address => mapping (address => uint256)) allowed;
  
  event Transfer(address indexed from, address indexed to, uint tokens);
  event Approval(address indexed tokenOwner, address indexed spender, uint tokens);
  event TokenBurn(address tokenOwner, uint tokens);
  
  constructor(string _name, string _symbol, uint256 _tS) public {
    issuer = IssuingEntity(msg.sender);
    issuerID = issuer.issuerID();
    registrar = InvestorRegistrar(issuer.registrar());
    name = _name;
    symbol = _symbol;
    balances[msg.sender] = _tS;
    totalSupply = _tS;
  }
  
  function() public payable {
    revert();
  }
  
  function circulatingSupply() public view returns (uint256) {
    return totalSupply.sub(balanceOf(address(issuer)));
  }
  
  function treasurySupply() public view returns (uint256) {
    return balanceOf(address(issuer));
  }

  
  function balanceOf(address _owner) public view returns (uint256) {
    return balances[_owner];
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
  
  function checkTransfer(address _from, address _to, uint256 _value) public view returns (bool) {
    bytes32 _idFrom = registrar.idMap(_from);
    bytes32 _idTo = registrar.idMap(_to); 
    require (countryLock[registrar.getCountry(_idFrom)] < now);
    require (countryLock[registrar.getCountry(_idTo)] < now);
    require (issuer.checkTransfer(_idFrom, _idTo, _value));
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
      require (checkTransfer(_from, _to, _value));
    }
    require (issuer.transferOwnership(_from, _to, _value));
    _setBalance(_from, balances[_from], balances[_from].sub(_value));
    _setBalance(_to, balances[_to], balances[_to].add(_value));
    emit Transfer(_from, _to, _value);
  }
  
  
  function _setBalance(address _owner, uint256 _old, uint256 _new) internal {
    balances[_owner] = _new;
    for (uint256 i = 0; i < checkpoints.length; i++) {
      if (address(checkpoints[i]) != 0) {
        checkpoints[i].balanceChanged(_owner, _old, _new);
      }
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
    if (
      registrar.idMap(_from) != registrar.idMap(msg.sender) &&
      (registrar.idMap(msg.sender) != issuerID)
    )
    {
      allowed[_from][msg.sender] = allowed[_from][msg.sender].sub(_value);
    }
    _transfer(_from, _to, _value);
    return true;
  }
  
  function _setTotalSupply(uint256 _value) internal {
    for (uint256 i = 0; i < checkpoints.length; i++) {
      if (address(checkpoints[i]) != 0) {
        checkpoints[i].totalSupplyChanged(totalSupply, _value);
      }
    }
    totalSupply = _value;
  }
  
  function burnTokens(uint _value) public onlyIssuer {
    address _issuer = address(issuer);
    _setBalance(_issuer, balances[_issuer], balances[_issuer].sub(_value));
    _setTotalSupply(totalSupply.sub(_value));
    emit Transfer(_issuer, 0, _value);
    emit TokenBurn(_issuer, _value);
  }
  
  function mintTokens(uint _value) public onlyIssuer {
    address _issuer = address(issuer);
    _setBalance(_issuer, balances[_issuer], balances[issuer].add(_value));
    _setTotalSupply(totalSupply.add(_value));
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
  
  function dexTransfer(
    address _from, 
    address _to, 
    uint256 _value,
     bool _locked
  ) 
    public
    onlyUnlocked 
    returns (bool) 
  {
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
  
  function attachBalanceModule(address _module) public onlyIssuer {
    CheckpointModule b = CheckpointModule(_module);
    require (b.token() == address(this));
    bool set;
    for (uint256 i = 0; i < checkpoints.length; i++) {
      require (address(checkpoints[i]) != _module);
      if (address(checkpoints[i]) == 0) {
        checkpoints[i] = b;
        set = true;
      }
    }
    if (!set) checkpoints.push(b);
  }

  function detachBalanceModule(address _module) public returns (bool) {
    if (_module != msg.sender) {
      require (registrar.idMap(msg.sender) == issuerID);
    }
    for (uint256 i = 0; i < checkpoints.length; i++) {
      if (address(checkpoints[i]) == _module) {
        checkpoints[i] = CheckpointModule(0);
        return true;
      }
    }
    revert();
  }

}