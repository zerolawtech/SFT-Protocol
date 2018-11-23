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
contract Custodian is Modular, MultiSig {

	/* issuer contract => investor ID => token addresses */
	mapping (address => mapping(bytes32 => address[])) beneficialOwners;
	/* token contract => issuer contract */
	mapping (address => address) issuerMap;

	event ReceivedTokens(
		address indexed issuer,
		address indexed token,
		bytes32 indexed investorID,
		uint256 amount
	);
	event SentTokens(
		address indexed issuer,
		address indexed token,
		address indexed recipient,
		uint256 amount
	);
	event NewBeneficialOwner(
		address indexed issuer,
		address indexed token,
		bytes32 indexed investorID
	);
	event RemovedBeneficialOwner(
		address indexed issuer,
		address indexed token,
		bytes32 indexed investorID
	);


	/**
		@notice Custodian constructor
		@param _owners Array of addresses to associate with owner
		@param _threshold multisig threshold for owning authority
	 */
	constructor(
		address[] _owners,
		uint32 _threshold
	)
		MultiSig(_owners, _threshold)
		public
	{

	}

	/**
		@notice Custodian transfer function
		@dev
			Addresses associated to the custodian cannot directly hold tokens,
			so they must use this transfer function to move them.
		@param _token Address of the token to transfer
		@param _to Address of the recipient
		@param _value Amount to transfer
		@param _stillOwner is recipient still a beneficial owner for this token?
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
		if (!isActiveModule(msg.sender) && !_checkMultiSig()) return false;
		SecurityToken t = SecurityToken(_token);
		require(t.transfer(_to, _value));
		IssuingEntity i = IssuingEntity(issuerMap[_token]);
		bytes32[] memory _id = new bytes32[](1);
		_id[0] = i.getID(_to);
		if (!_stillOwner) {
			_removeInvestors(_token, _id);
		}
		/* bytes4 signature for custodian module sentTokens() */
		_callModules(0x31b45d35, abi.encode(
			_token,
			_id[0],
			_value,
			_stillOwner
		));
		emit SentTokens(issuerMap[_token], _token, _to, _value);
		return true;
	}

	/**
		@notice Add a new token owner
		@dev called by IssuingEntity when tokens are transferred to a custodian
		@param _token Token address
		@param _id Investor ID
		@param _value Amount transferred
		@return bool was investor already a beneficial owner of this issuer?
	 */
	function receiveTransfer(
		address _token,
		bytes32 _id,
		uint256 _value
	)
		external
		returns (bool)
	{
		if (issuerMap[_token] == 0) {
			require(SecurityToken(_token).issuer() == msg.sender);
			issuerMap[_token] = msg.sender;
		} else {
			require(issuerMap[_token] == msg.sender);
		}
		emit ReceivedTokens(msg.sender, _token, _id, _value);
		address[] storage _owner = beneficialOwners[msg.sender][_id];
		bool _known;
		for (uint256 i = 0; i < _owner.length; i++) {
			if (_owner[i] == _token) {
				_known = true;
				break;
			}
		}
		if (!_known) {
			_owner.push(_token);
			emit NewBeneficialOwner(msg.sender, _token, _id);
		}
		/* bytes4 signature for custodian module receivedTokens() */
		_callModules(0x081e5f03, abi.encode(_token, _id, _value, !_known));
		/*
			return true if custodian did not previously hold any tokens
			from this issuer for this investor 
		*/
		return (!_known && _owner.length == 1) ? true : false;
	}

	/**
		@notice Add beneficial token owners
		@dev Increases the investor count in the IssuingEntity contract
		@param _token Token address
		@param _id Array of investor IDs
		@return bool success
	 */
	function addInvestors(
		address _token,
		bytes32[] _id
	)
		external
		returns (bool)
	{
		if (!isActiveModule(msg.sender) && !_checkMultiSig()) return false;
		address _issuer = issuerMap[_token];
		for (uint256 i = 0; i < _id.length; i++) {
			address[] storage _owner = beneficialOwners[_issuer][_id[i]];
			bool _found;
			for (uint256 x = 0; x < _owner.length; x++) {
				if (_owner[x] == _token) {
					_found = true;
					break;
				}
			}
			if (!_found) {
				_owner.push(_token);
				emit NewBeneficialOwner(_issuer, _token, _id[i]);
			}
		}
		require(IssuingEntity(_issuer).setBeneficialOwners(ownerID, _id, true));
		/* bytes4 signature for custodian module addedInvestors() */
		_callModules(0xf8324d5a, msg.data);
		return true;
	}

	/**
		@notice Remove beneficial token owners
		@dev Decreases the investor count in the IssuingEntity contract
		@param _token Token address
		@param _id Array of investor IDs
		@return bool success
	 */
	function removeInvestors(
		address _token,
		bytes32[] _id
	)
		external
		returns (bool)
	{
		if (!isActiveModule(msg.sender) && !_checkMultiSig()) return false;
		_removeInvestors(_token, _id);
		/* bytes4 signature for custodian module removedInvestors() */
		_callModules(0x9898b82e, msg.data);
		return true;
	}

	/**
		@notice internal to remove beneficial token owners
		@param _token Token address
		@param _id Array of investor IDs
	 */
	function _removeInvestors(address _token, bytes32[] _id) internal {
		address _issuer = issuerMap[_token];
		bytes32[] memory _toRemove = new bytes32[](_id.length);
		for (uint256 i = 0; i < _id.length; i++) {
			address[] storage _owner = beneficialOwners[_issuer][_id[i]];
			for (uint256 x = 0; x < _owner.length; x++) {
				if (_owner[x] == _token) {
					_owner[x] = _owner[_owner.length-1];
					/*
						underflow is impossible because for loop would not
						start with an empty array. */
					_owner.length -= 1;
					emit RemovedBeneficialOwner(_issuer, _token, _id[i]);
					if (_owner.length > 0) break;
					_toRemove[i] = _id[i];
					break;
				}
			}
		}
		require(IssuingEntity(_issuer).setBeneficialOwners(
			ownerID,
			_toRemove,
			false
		));
	}

	/**
		@notice Attach a module
		@dev
			Modules have a lot of permission and flexibility in what they
			can do. Only attach a module that has been properly auditted and
			where you understand exactly what it is doing.
			https://sft-protocol.readthedocs.io/en/latest/modules.html
		@param _module Address of the module contract
		@return bool success
	 */
	function attachModule(
		address _module
	)
		external
		returns (bool)
	{
		if (!_checkMultiSig()) return false;
		_attachModule(_module);
		return true;
	}

	/**
		@notice Detach a module
		@dev This function may also be called by the module itself.
		@param _module Address of the module contract
		@return bool success
	 */
	function detachModule(
		address _module
	)
		external
		returns (bool)
	{
		if (_module != msg.sender) {
			if (!_checkMultiSig()) return false;
		}
		_detachModule(_module);
		return true;
	}

}
