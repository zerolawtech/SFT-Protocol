pragma solidity ^0.4.24;

import "./open-zeppelin/SafeMath.sol";
import "./SecurityToken.sol";
import "./components/MultiSig.sol";

/**
	@title Custodian Contract
	@dev
		This is a bare-bones implementation of a custodian contract,
		it can be expanded upon depending on the needs of the owner.
 */
contract Custodian is MultiSigMultiOwner {


	bytes32 public id;

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
		uint32 _threshold
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
		@param _stillOwner bool is recipient still a beneficial owner?
		@return bool success
	 */
	function transfer(
		address _token,
		address _to,
		uint256 _value,
		bool _stillOwner
	)
		external
		returns (bool)
	{
		if (!_checkMultiSig()) return false;
		SecurityToken t = SecurityToken(_token);
		require(t.transfer(_to, _value));
		if (!_stillOwner) {
			IssuingEntity i = IssuingEntity(issuerContracts[_token]);
			bytes32[] memory _id = new bytes32[](1);
			_id[0] = i.getID(_to);
			_removeInvestors(_token, _id);
		}
		return true;
	}

	/**
		@notice Add a new token owner
		@dev called by IssuingEntity when tokens are transferred to a custodian
		@param _token Token address
		@param _id Investor ID
		@return bool success
	 */
	function receiveTransfer(address _token, bytes32 _id) external returns (bool) {
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
		/* return true if investor previously held no tokens for this issuer */
		return _owner.length == 1 ? true : false;
	}

	/**
		@notice Add beneficial token owners
		@dev Increases the investor count in the IssuingEntity contract
		@param _token Token address
		@param _id Array of investor IDs
		@return bool success
	 */
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
		require(IssuingEntity(_issuer).setBeneficialOwners(_id, true));
		return true;
	}

	/**
		@notice Remove beneficial token owners
		@dev Decreases the investor count in the IssuingEntity contract
		@param _token Token address
		@param _id Array of investor IDs
		@return bool success
	 */
	function removeInvestors(address _token, bytes32[] _id) external returns (bool) {
		if (!_checkMultiSig()) return false;
		_removeInvestors(_token, _id);
		return true;
	}

	/**
		@notice internal to remove beneficial token owners
		@param _token Token address
		@param _id Array of investor IDs
	 */
	function _removeInvestors(address _token, bytes32[] _id) internal {
		address _issuer = issuerContracts[_token];
		bytes32[] memory _toRemove = new bytes32[](_id.length);

		for (uint256 i = 0; i < _id.length; i++) {
			address[] storage _owner = beneficialOwners[_issuer][_id[i]];
			for (uint256 x = 0; x < _owner.length; x++) {
				if (_owner[x] == _token) {
					_owner[x] = _owner[_owner.length-1];
					_owner.length -= 1;
					if (_owner.length > 0) break;
					_toRemove[i] = _id[i];
					break;
				}
			}
		}
		require(IssuingEntity(_issuer).setBeneficialOwners(_toRemove, false));
	}

}
