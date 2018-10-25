pragma solidity ^0.4.24;

import "./SecurityToken.sol";
import "./MultiSig.sol";

/// @title Custodian Contract
contract Custodian is MultiSig {

	string public name;
	bytes32 public id;
	mapping (address => bool) public addresses;

	constructor(
		string _name,
		address[] _owners,
		uint64 _threshold
	)
		MultiSig
	(
		_owners,
		_threshold
	)
		public
	{
		name = _name;
		id = keccak256(abi.encodePacked(address(this)));
	}

	function transfer(
		address _token,
		address _to,
		uint256 _value
	)
		external
		onlyOwner
		returns (bool)
	{
		require(SecurityToken(_token).transfer(_to, _value));
		return true;
	}

}
