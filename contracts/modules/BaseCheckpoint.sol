pragma solidity ^0.4.24;

import "./Base.sol";


contract CheckpointModule is ModuleBase {

  uint256 time;
  uint256 totalSupply;
  mapping (address => uint256) balance;
  mapping (address => bool) zeroBalance;
  
  constructor(address _token, uint256 _time) ModuleBase(_token) public {
    require (_time >= now);
    totalSupply = token.totalSupply();
    time = _time;
  }
  
  function _getBalance(address _owner) internal view returns (uint256) {
    if (balance[_owner] > 0) return balance[_owner];
    if (zeroBalance[_owner]) return 0;
    return token.balanceOf(_owner);
  }
  
  function balanceChanged(address _owner, uint256 _old, uint256) external onlyToken returns (bool) {
    if (now < time) return true;
    if (balance[_owner] > 0) return true;
    if (zeroBalance[_owner]) return true;
    if (_old > 0) {
      balance[_owner] = _old;
    } else {
      zeroBalance[_owner] = true;
    }
    return true;
  }
  
  function totalSupplyChanged(uint256, uint256 _new) external onlyToken returns (bool) {
    if (now < time) {
      totalSupply = _new;
    }
    return true;
  }

  function getBindings() external pure returns (bool, bool, bool) {
    return (false, true, true);
  }

}