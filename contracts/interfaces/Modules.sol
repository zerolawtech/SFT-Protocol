pragma solidity ^0.4.24;


interface IBaseModule {
	function getBindings() external view returns (bytes4[]);
	function owner() external view returns (address);
	function name() external view returns (string);
}

interface ISTModule {
	function getBindings() external view returns (bytes4[]);
	function token() external returns (address);
	function owner() external view returns (address);
	function name() external view returns (string);
	
	/* 0x70aaf928 */
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
	
	/* 0x35a341da */
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
	
	/* 0x4268353d */
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
}

interface IIssuerModule {
	function getBindings() external view returns (bytes4[]);
	function issuer() external returns (address);
	function owner() external view returns (address);
	function name() external view returns (string);

	/* 0x47fca5df */
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
	
	/* 0x0cfb54c9 */
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
	
	/* 0x4268353d */
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
}
