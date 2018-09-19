pragma solidity ^0.4.24;


interface STModule {
  function checkTransfer(address _from, address _to, uint256 _value) external view returns (bool);
  function balanceChanged(address _owner, uint256 _old, uint256 _new) external returns (bool);
  function totalSupplyChanged (uint256 _old, uint256 _new) external returns (bool);
  function getBindings() external view returns (bool, bool, bool);
  function token() external returns (address);
}