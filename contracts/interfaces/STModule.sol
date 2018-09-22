pragma solidity ^0.4.24;


interface BaseModule {
  function getBindings() external view returns (bool, bool, bool);
  function owner() external view returns (address);
}

interface STModule {
  function checkTransfer(address _from, address _to, uint256 _value) external view returns (bool);
  function transferTokens(address _from, address _to, uint256 _value) external view returns (bool);
  function balanceChanged(address _owner, uint256 _old, uint256 _new) external returns (bool);
  function getBindings() external view returns (bool, bool, bool);
  function token() external returns (address);
  function owner() external view returns (address);
}

interface IssuerModule {
  function checkTransfer(address _token, address _from, address _to, uint256 _value) external view returns (bool);
  function transferTokens(address _token, address _from, address _to, uint256 _value) external view returns (bool);
  function balanceChanged(address _token, address _owner, uint256 _old, uint256 _new) external returns (bool);
  function getBindings() external view returns (bool, bool, bool);
  function issuer() external returns (address);
  function owner() external view returns (address);
}