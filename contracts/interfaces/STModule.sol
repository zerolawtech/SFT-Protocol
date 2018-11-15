pragma solidity ^0.4.24;


interface IBaseModule {
	function getBindings() external view returns (bool, bool, bool);
	function owner() external view returns (address);
	function name() external view returns (string);
}

interface ISTModule {
	function checkTransfer(
		address[2] _addr,
		bytes32 _authID,
		bytes32[2] _id,
		uint8[2] _rating,
		uint16[2] _country,
		uint256 _value
	)
		external
		view
		returns (bool);
	function transferTokens(
		address[2] _addr,
		bytes32[2] _id,
		uint8[2] _rating,
		uint16[2] _country,
		uint256 _value
	)
		external
		view
		returns (bool);
	function balanceChanged(
		address _addr,
		bytes32 _id,
		uint8 _rating,
		uint16 _country,
		uint256 _old,
		uint256 _new
	)
		external
		returns (bool);
	function getBindings() external view returns (
		bool _checkTransfer,
		bool _transferTokens, 
		bool _balanceChanged);
	function token() external returns (address);
	function owner() external view returns (address);
}

interface IIssuerModule {
	function checkTransfer(
		address _token,
		bytes32 _authID,
		bytes32[2] _id,
		uint8[2] _rating,
		uint16[2] _country,
		uint256 _value
	)
		external
		view
		returns (bool);
	function transferTokens(
		address _token,
		bytes32[2] _id,
		uint8[2] _rating,
		uint16[2] _country,
		uint256 _value
	)
		external
		view
		returns (bool);
	function balanceChanged(
		address _token,
		bytes32 _id,
		uint8 _rating,
		uint16 _country,
		uint256 _old,
		uint256 _new
	)
		external
		returns (bool);
	function getBindings() external view returns (
		bool _checkTransfer,
		bool _transferTokens, 
		bool _balanceChanged);
	function issuer() external returns (address);
	function owner() external view returns (address);
}
