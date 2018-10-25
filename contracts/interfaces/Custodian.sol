pragma solidity ^0.4.24;


interface ICustodian {

	function name() external view returns (string);
	function id() external view returns (bytes32);
	function addresses(address) external view returns (bool);

	function transfer(address _token, address _to, uint256 _value) external returns (bool);
}
