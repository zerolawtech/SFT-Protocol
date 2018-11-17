pragma solidity ^0.4.24;

import "./open-zeppelin/SafeMath.sol";
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

	using SafeMath64 for uint64;

	bytes32 public id;
	mapping (address => bool) public addresses;

	// issuer contract => investor ID => array of token addresses
	mapping (address => mapping(bytes32 => address[])) beneficialOwners;
	mapping (address => address) issuerContracts;


	/**
		@notice Custodian constructor
		@param _owners Array of addresses to associate with owner
		@param _threshold multisig threshold for owning authority
	 */
	constructor(
		address[] _owners,
		uint64 _threshold
	)
		MultiSigMultiOwner(_owners, _threshold)
		public
	{
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
		uint256 _value,
		bool _remove
	)
		external
		returns (bool)
	{
		if (!_checkMultiSig()) return false;
		SecurityToken t = SecurityToken(_token);
		require(t.transfer(_to, _value));
		if (_remove) {
			IssuingEntity i = IssuingEntity(issuerContracts[_token]);
			_removeInvestor(_token, i.getID(_to));
		}
		return true;
	}

	function addInvestors(address _token, bytes32[] _id) external returns (bool) {
		if (!_checkMultiSig()) return false;
		address _issuer = issuerContracts[_token];
		for (uint256 i = 0; i < _id.length; i++) {
			address[] storage _owner = beneficialOwners[_issuer][_id[i]];
			bool _found = false;
			for (uint256 x = 0; x < _owner.length; x++) {
				if (_owner[x] == _token) {
					_found = true;
					break;
				}
			}
			if (!_found) {
				_owner.push(_token);
			}
		}
		require(IssuingEntity(_issuer).addCustodianInvestors(_id));
		return true;
	}

	function newInvestor(address _token, bytes32 _id) external returns (bool) {
		if (issuerContracts[_token] == 0) {
			require(SecurityToken(_token).issuer() == msg.sender);
			issuerContracts[_token] = msg.sender;
		} else {
			require(issuerContracts[_token] == msg.sender);
		}
		address[] storage _owner = beneficialOwners[msg.sender][_id];
		for (uint256 i = 0; i < _owner.length; i++) {
			if (_owner[i] == _token) return false;
		}
		_owner.push(_token);
		return true;
	}

	function removeInvestors(address[] _token, bytes32[] _id) external returns (bool) {
		require(_token.length == _id.length);
		if (!_checkMultiSig()) return false;
		for (uint256 i = 0; i < _token.length; i++) {
			_removeInvestor(_token[i], _id[i]);
		}
		return true;
	}

	function _removeInvestor(address _token, bytes32 _id) internal {
		address[] storage _inv = beneficialOwners[_token][_id];
		for (uint256 i = 0; i < _inv.length; i++) {
			if (_inv[i] == _token) {
				_inv[i] = _inv[_inv.length-1];
				_inv.length -= 1;
				if (_inv.length > 0) return;
				require(IssuingEntity(issuerContracts[_token]).removeCustodianInvestor(_id));
				return;
			}
		}
	}

}
