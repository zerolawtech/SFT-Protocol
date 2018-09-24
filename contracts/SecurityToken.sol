pragma solidity ^0.4.24;


import "./open-zeppelin/SafeMath.sol";
import "./IssuingEntity.sol";
import "./Base.sol";

contract SecurityToken is STBase {

  using SafeMath for uint256;

  IssuingEntity public issuer;
  uint8 public constant decimals = 0;
  string public name;
  string public symbol;
  uint256 public totalSupply;

  mapping (address => uint256) balances; 
  mapping (address => mapping (address => uint256)) allowed;

  event Transfer(address from, address to, uint tokens);
  event Approval(address tokenOwner, address spender, uint tokens);
  event BalanceChanged(address owner, uint256 oldBalance, uint256 newBalance);

  constructor(string _name, string _symbol, uint256 _totalSupply) public {
    issuer = IssuingEntity(msg.sender);
    issuerID = issuer.issuerID();
    registrar = KYCRegistrar(issuer.registrar());
    name = _name;
    symbol = _symbol;
    balances[msg.sender] = _totalSupply;
    totalSupply = _totalSupply;
    emit Transfer(0, msg.sender, _totalSupply);
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

  function checkTransfer(
    address _from, 
    address _to, 
    uint256 _value
  ) 
    public 
    view 
    returns (bool) 
  {
    require (_value > 0);
    for (uint256 i = 0; i < modules.length; i++) {
      if (address(modules[i].module) != 0 && modules[i].checkTransfer) {
        require(STModule(modules[i].module).checkTransfer(_from, _to, _value));
      }
    }
    require (issuer.checkTransfer(address(this), _from, _to, _value));
    return true;
  }

  function transfer(address _to, uint256 _value) public onlyUnlocked returns (bool) {
    require (registrar.isPermittedAddress(msg.sender));
    _transfer(msg.sender, _to, _value);
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
    bytes32 _sendId = registrar.getId(msg.sender);
    bytes32 _fromId = registrar.getId(_from);
    if (
      _sendId != _fromId &&
      _sendId != issuerID &&
      !isActiveModule(msg.sender)
    )
    {
      allowed[_from][msg.sender] = allowed[_from][msg.sender].sub(_value);
    } else if (_sendId == _fromId) {
      require (registrar.isPermittedAddress(msg.sender));
    }
    _transfer(_from, _to, _value);
    return true;
  }

  function _transfer(address _from, address _to, uint256 _value) internal {
    if (registrar.getId(_from) == issuerID) {
      _from = address(issuer);
    }
    require (checkTransfer(_from, _to, _value));
    balances[_from] = balances[_from].sub(_value);
    balances[_to] = balances[_to].add(_value);
    
    for (uint256 i = 0; i < modules.length; i++) {
      if (address(modules[i].module) != 0 && modules[i].transferTokens) {
        require (STModule(modules[i].module).transferTokens(_from, _to, _value));
      }
    }
    require (issuer.transferTokens(address(this), _from, _to, _value));
    emit Transfer(_from, _to, _value);
  }
  
  function modifyBalance(address _owner, uint256 _value) public returns (bool) {
    require (isActiveModule(msg.sender));
    if (balances[_owner] == _value) return true;
    if (balances[_owner] > _value) {
      totalSupply = totalSupply.sub(balances[_owner].sub(_value));
    } else {
      totalSupply = totalSupply.add(_value.sub(balances[_owner]));
    }
    
    uint256 _old = balances[_owner];
    balances[_owner] = _value;
    for (uint256 i = 0; i < modules.length; i++) {
      if (address(modules[i].module) != 0 && modules[i].balanceChanged) {
        require (STModule(modules[i].module).balanceChanged(_owner, _old, _value));
      }
    }
    require (issuer.balanceChanged(address(this), _owner, _old, _value));
    emit BalanceChanged(_owner, _old, _value);
  }

  function isActiveModule(address _module) public view returns (bool) {
    if (activeModules[_module]) return true;
    return issuer.isActiveModule(_module);
  }
  


}