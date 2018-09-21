pragma solidity ^0.4.24;


import "./open-zeppelin/safemath.sol";
import "./company.sol";
import "./base.sol";
import "./interfaces/STModule.sol";

contract SecurityToken is STBase {

  using SafeMath for uint256;

  IssuingEntity public issuer;
  uint8 public constant decimals = 0;
  string public name;
  string public symbol;
  uint256 public totalSupply;

  mapping (address => uint256) balances; 
  mapping (address => mapping (address => uint256)) allowed;

  constructor(string _name, string _symbol, uint256 _totalSupply) public {
    issuer = IssuingEntity(msg.sender);
    issuerID = issuer.issuerID();
    registrar = InvestorRegistrar(issuer.registrar());
    name = _name;
    symbol = _symbol;
    balances[msg.sender] = _totalSupply;
    totalSupply = _totalSupply;
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

  function transfer(address _to, uint256 _value) public onlyUnlocked returns (bool) {
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
    if (
      registrar.idMap(_from) != registrar.idMap(msg.sender) &&
      registrar.idMap(msg.sender) != issuerID &&
      !activeModules[msg.sender]
    )
    {
      allowed[_from][msg.sender] = allowed[_from][msg.sender].sub(_value);
    }
    _transfer(_from, _to, _value);
    return true;
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
    for (uint256 i = 0; i < modules.length; i++) {
      if (address(modules[i].module) != 0 && modules[i].checkTransfer) {
        require(modules[i].module.checkTransfer(_from, _to, _value));
      }
    }
    return true;
  }

  function _transfer(address _from, address _to, uint256 _value) internal {
    if (registrar.idMap(_from) == issuerID) {
      _from = address(issuer);
    } else {
      require (checkTransfer(_from, _to, _value));
    }
    _setBalance(_from, balances[_from].sub(_value));
    _setBalance(_to, balances[_to].add(_value));
  }

  function _setBalance(address _owner, uint256 _value) internal {
    uint256 _old = balances[_owner];
    balances[_owner] = _value;
    for (uint256 i = 0; i < modules.length; i++) {
      if (address(modules[i].module) != 0 && modules[i].balanceChanged) {
        require (modules[i].module.balanceChanged(_owner, _old, _value));
      }
    }
  }


  mapping (address => bool) activeModules;
  function modifyBalance(address _owner, uint256 _value) public returns (bool) {
    require (activeModules[msg.sender]);
    if (balances[_owner] == _value) return true;
    uint256 _old = totalSupply;
    if (balances[_owner] > _value) {
      totalSupply = totalSupply.sub(balances[_owner].sub(_value));
    } else {
      totalSupply = totalSupply.add(_value.sub(balances[_owner]));
    }
    _setBalance(_owner, _value);
    for (uint256 i = 0; i < modules.length; i++) {
      if (address(modules[i].module) != 0 && modules[i].balanceChanged) {
        require (modules[i].module.totalSupplyChanged(_old, totalSupply));
      }
    }
  }

  struct Module {
    STModule module;
    bool checkTransfer;
    bool balanceChanged;
    bool tsChanged;
  } 

  Module[] modules;
  function attachModule(address _module) public onlyIssuer returns (bool) {
    require (!checkModuleAttached(_module));
    STModule m = STModule(_module);
    require (m.token() == address(this));
    (bool _ct, bool _bc, bool _ts) = m.getBindings();
    bool set;
    activeModules[_module] = true;
    for (uint256 i = 0; i < modules.length; i++) {
      if (address(modules[i].module) == 0) {
        modules[i].module = m;
        modules[i].checkTransfer = _ct;
        modules[i].balanceChanged = _bc;
        modules[i].tsChanged = _ts;
        set = true;
      }
    }
    if (!set) {
      modules.push(Module(m, _ct, _ts, _bc));
    }
    return true;
  }

  function detachModule(address _module) public returns (bool) {
    if (_module != msg.sender) {
      require (registrar.idMap(msg.sender) == issuerID);
    }
    for (uint256 i = 0; i < modules.length; i++) {
      if (address(modules[i].module) == _module) {
        modules[i].module = STModule(0);
        activeModules[_module] = false;
        return true;
      }
    }
    revert();
  }

  function checkModuleAttached(address _module) public view returns (bool) {
    for (uint256 i = 0; i < modules.length; i++) {
      if (address(modules[i].module) == _module) {
        return true;
      }
    }
    return false;
  }


}