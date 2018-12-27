pragma solidity >=0.4.24 <0.5.0;

import "./open-zeppelin/SafeMath.sol";
import "./SecurityToken.sol";
import "./components/Modular.sol";
import "./components/MultiSig.sol";

/** @title Custodian Contract */
contract Custodian is Modular, MultiSig {

	using SafeMath32 for uint32;
	using SafeMath for uint256;

	/* issuer contract => investor ID => token addresses */
	// mapping (address => mapping(bytes32 => address[])) beneficialOwners;
	
	/* token contract => issuer contract */
	mapping (address => IssuingEntity) issuerMap;
	
	mapping (bytes32 => Investor) investors;

	struct Balance {
		uint256 balance;
		bool isOwner;
	}
	
	struct Issuer {
		uint32 tokenCount;
		bool isOwner;
	}
	
	struct Investor {
		mapping (address => Issuer) issuers;
		mapping (address => uint256) balances;
	}

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

	/** @notice fallback function, allows contract to receive ether */
	function () external payable {
		return;
	}

	/**
		@notice Allows custodian to transfer ether out the contract
		@dev Useful for dividend distributions
		@param _to Array of address to transfer to
		@param _value Array of amounts to transfer
		@return bool success
	 */
	function transferEther(
		address[] _to,
		uint256[] _value
	)
		external
		returns (bool)
	{
		if (!_checkMultiSig()) return false;
		require (_to.length == _value.length);
		for (uint256 i = 0; i < _to.length; i++) {
			_to[i].transfer(_value[i]);
		}
		return true;
	}


	function balanceOf(
		bytes32 _id,
		address _token
	)
		external
		view
		returns (uint256)
	{
		return investors[_id].balances[_token];
	}

	function isBeneficialOwner(
		bytes32 _id,
		address _issuer
	)
		external
		view
		returns (bool)
	{
		return investors[_id].issuers[_issuer].isOwner;
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
		SecurityToken _token,
		address _to,
		uint256 _value,
		bool _stillOwner
	)
		external
		returns (bool)
	{
		if (!isActiveModule(msg.sender) && !_checkMultiSig()) return false;
		bytes32 _id = issuerMap[_token].getID(_to);
		Investor storage i = investors[_id];
		i.balances[_token] = i.balances[_token].sub(_value);
		require(_token.transfer(_to, _value));
		if (i.balances[_token] == 0) {
			Issuer storage issuer = i.issuers[issuerMap[_token]];
			issuer.tokenCount = issuer.tokenCount.sub(1);
			if (issuer.tokenCount == 0 && !_stillOwner) {
				issuer.isOwner = false;
				issuerMap[_token].setBeneficialOwners(ownerID, _id, false);
			}
		}
		/* bytes4 signature for custodian module sentTokens() */
		_callModules(0x31b45d35, abi.encode(
			_token,
			_id,
			_value,
			issuer.isOwner
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
		if (issuerMap[_token] == address(0)) {
			require(SecurityToken(_token).issuer() == msg.sender);
			issuerMap[_token] = IssuingEntity(msg.sender);
		} else {
			require(issuerMap[_token] == msg.sender);
		}
		emit ReceivedTokens(msg.sender, _token, _id, _value);
		Investor storage i = investors[_id];
		bool _known;
		if (i.balances[_token] == 0) {
			Issuer storage issuer = i.issuers[msg.sender];
			issuer.tokenCount = issuer.tokenCount.add(1);
			if (!issuer.isOwner) {
				issuer.isOwner = true;
				_known = true;
			}
		}
		i.balances[_token] = i.balances[_token].add(_value);
		/* bytes4 signature for custodian module receivedTokens() */
		_callModules(0x081e5f03, abi.encode(_token, _id, _value, !_known));
		return _known;
	}

	function transferInternal(
		SecurityToken _token,
		bytes32 _fromID,
		bytes32 _toID,
		uint256 _value,
		bool _stillOwner
	)
		external
		returns (bool)
	{
		if (!isActiveModule(msg.sender) && !_checkMultiSig()) return false;
		Investor storage from = investors[_fromID];
		require(from.balances[_token] >= _value, "Insufficient balance");
		Investor storage to = investors[_toID];
		from.balances[_token] = from.balances[_token].sub(_value);
		to.balances[_token] = to.balances[_token].add(_value);
		if (to.balances[_token] == _value) {
			Issuer storage issuer = to.issuers[issuerMap[_token]];
			issuer.tokenCount = issuer.tokenCount.add(1);
			if (!issuer.isOwner) {
				issuer.isOwner = true;
			}
		}
		issuer = from.issuers[issuerMap[_token]];
		if (from.balances[_token] == 0) {
			issuer.tokenCount = issuer.tokenCount.sub(1);
			if (issuer.tokenCount == 0 && !_stillOwner) {
				issuer.isOwner = false;
			}
		}
		require(_token.transferCustodian([_fromID, _toID], _value, issuer.isOwner));
		return true;
	}

	function checkTransferInternal(
		SecurityToken _token,
		bytes32 _fromID,
		bytes32 _toID,
		uint256 _value,
		bool _stillOwner
	)
		external
		view
		returns (bool)
	{
		Investor storage from = investors[_fromID];
		require(from.balances[_token] >= _value, "Insufficient balance");
		if (
			!_stillOwner &&
			from.balances[_token] == _value &&
			from.issuers[issuerMap[_token]].tokenCount == 1
		) {
			bool _owner;
		} else {
			_owner = true;
		}
		require (_token.checkTransferCustodian([_fromID, _toID], _owner));
		return true;
	}

	function setOwnership(
		bytes32 _id,
		address _issuer,
		bool _isOwner
	)
		external
		returns (bool)
	{
		if (!isActiveModule(msg.sender) && !_checkMultiSig()) return false;
		Issuer storage i = investors[_id].issuers[_issuer];
		if (i.tokenCount == 0 && i.isOwner != _isOwner) {
			i.isOwner = _isOwner;
			IssuingEntity(_issuer).setBeneficialOwners(ownerID, _id, _isOwner);
		}
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
