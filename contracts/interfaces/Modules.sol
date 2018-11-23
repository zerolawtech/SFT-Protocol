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

interface ICustodianModule {
	function getBindings() external view returns (bytes4[]);
	function owner() external view returns (address);
	function name() external view returns (string);

	/* 0xc221a3b5 */
	function sentTokens(
		address _token,
		address _to,
		uint256 _value,
		bool _stillOwner
	)
		external
		returns (bool);

	/* 0x081e5f03 */
	function receivedTokens(
		address _token,
		bytes32 _id,
		uint256 _value,
		bool _newOwner
	)
		external
		returns (bool);
	
	/* 0xf8324d5a */
	function addedInvestors(
		address _token,
		bytes32[] _id
	)
		external
		returns (bool);
	
	/* 0x9898b82e */
	function removedInvestors(
		address _token,
		bytes32[] _id
	)
		external
		returns (bool);
}