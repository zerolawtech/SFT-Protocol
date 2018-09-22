pragma solidity ^0.4.24;


import "../open-zeppelin/safemath.sol";
import "./Base.sol";

contract DEXModule is STModuleBase {

  using SafeMath for uint256;
  
  struct ExchangeBalance {
    uint256 total;
    mapping (bytes32 => uint256) exchange;
  }
  mapping (address => ExchangeBalance) exchangeBalances; 
  

  modifier onlyUnlocked() {
    require (!token.locked());
    _;
  }

  function getBindings() external view returns (bool, bool, bool) {
    return (true, false, false);
  }

  function checkTransfer(address _from, address, uint256 _value) external view returns (bool) {
    ExchangeBalance storage e = exchangeBalances[_from];
    require(token.balanceOf(_from).sub(_value) >= e.total);
    return true;
  }

  function dexApprove(bytes32 _id, uint256 _value) public returns (bool) {
    require (registrar.getType(_id) == 3);
    _dexLock(_id, msg.sender, _value);
    return true;
  }
  
  function _dexLock(bytes32 _id, address _owner, uint256 _value) internal {
    ExchangeBalance storage e = exchangeBalances[_owner];
    require (token.balanceOf(msg.sender) > e.total.add(_value));
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
    token.transferFrom(_from, _to, _value);
    if (_locked) {
      _dexLock(_id, _to, _value);
    }
    return true;
  }
  
  function dexBalanceOf(address _owner, bytes32 _exchangeID) public view returns (uint256) {
    return exchangeBalances[_owner].exchange[_exchangeID];
  }

}