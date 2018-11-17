pragma solidity ^0.4.24;

import "./SecurityToken.sol";
import "./components/MultiSig.sol";

/**
	@title Custodian Contract
	@dev
		This is a bare-bones implementation of a custodian contract,
		it should be expanded upon depending on the specific needs
		of the owner.
 */
contract Custodian is MultiSigMultiOwner {

	string public name;
	bytes32 public id;
	mapping (address => bool) public addresses;

	/**
		@notice Custodian constructor
		@param _name Human-readable name of custodian
		@param _owners Array of addresses to associate with owner
		@param _threshold multisig threshold for owning authority
	 */
	constructor(
		string _name,
		address[] _owners,
		uint64 _threshold
	)
		MultiSigMultiOwner(_owners, _threshold)
		public
	{
		name = _name;
		id = keccak256(abi.encodePacked(address(this)));
	}

	/**
		@notice Custodian transfer function
		@dev
			Addresses associated to the custodian cannot directly hold tokens,
			so they must use this transfer function to move them.
		@param _token Address of the token to transfer
		@param _to Address of the recipient
		@param _value Amount to transfer
		@return bool success
	 */
	function transfer(
		address _token,
		address _to,
		uint256 _value
	)
		external
		returns (bool)
	{
		if (!_checkMultiSig()) return false;
		require(SecurityToken(_token).transfer(_to, _value));
		return true;
	}

}
