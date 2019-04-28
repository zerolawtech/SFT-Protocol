pragma solidity >=0.4.24 <0.5.0;

import "../SecurityToken.sol";
import "../bases/Modular.sol";
import "../bases/MultiSig.sol";

/** @title Owned Custodian Contract */
contract OwnedCustodian is Modular, MultiSig {

	event ReceivedTokens(
		address indexed token,
		address indexed from,
		uint256 amount
	);
	event SentTokens(
		address indexed token,
		address indexed to,
		uint256 amount
	);
	event TransferOwnership(
		address indexed token,
		address indexed from,
		address indexed to,
		uint256 value
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
		@notice Fetch an investor's current token balance held by the custodian
		@param _token address of the SecurityToken contract
		@param _owner investor address
		@return integer
	 */
	function balanceOf(
		SecurityToken _token,
		address _owner
	)
		external
		view
		returns (uint256)
	{
		return _token.custodianBalanceOf(address(this), _owner);
	}


	/**
		@notice View function to check if an internal transfer is possible
		@param _token Address of the token to transfer
		@param _from Sender address
		@param _to Recipient address
		@param _value Amount of tokens to transfer
		@return bool success
	 */
	function checkCustodianTransfer(
		SecurityToken _token,
		address _from,
		address _to,
		uint256 _value
	)
		external
		view
		returns (bool)
	{
		return _token.checkTransferCustodian(address(this), _from, _to, _value);
	}

	/**
		@notice Transfers tokens out of the custodian contract
		@dev callable by custodian authorities and modules
		@param _token Address of the token to transfer
		@param _to Address of the recipient
		@param _value Amount to transfer
		@return bool success
	 */
	function transfer(
		SecurityToken _token,
		address _to,
		uint256 _value
	)
		external
		returns (bool)
	{
		if (
			/* msg.sig = 0xbeabacc8 */
			!isPermittedModule(msg.sender, msg.sig) &&
			!_checkMultiSig()
		) {
			return false;
		}
		require(_token.transfer(_to, _value));
		/* bytes4 signature for custodian module sentTokens() */
		require(_callModules(
			0xb4684410,
			0x00,
			abi.encode(_token, _to, _value)
		));
		emit SentTokens(_token, _to, _value);
		return true;
	}

	/**
		@notice Add a new token owner
		@dev called by IssuingEntity when tokens are transferred to a custodian
		@param _from Investor address
		@param _value Amount transferred
		@return bool success
	 */
	function receiveTransfer(
		address _from,
		uint256 _value
	)
		external
		returns (bool)
	{
		
		/* bytes4 signature for custodian module receivedTokens() */
		require(_callModules(
			0xb15bcbc4,
			0x00,
			abi.encode(msg.sender, _from, _value)
		));
		emit ReceivedTokens(msg.sender, _from, _value);
		return true;
	}

	/**
		@notice Transfer token ownership within the custodian
		@dev Callable by custodian authorities and modules
		@param _token Address of the token to transfer
		@param _from Sender address
		@param _to Recipient address
		@param _value Amount of tokens to transfer
		@return bool success
	 */
	function transferInternal(
		SecurityToken _token,
		address _from,
		address _to,
		uint256 _value
	)
		external
		returns (bool)
	{
		if (
			/* msg.sig = 0x2f98a4c3 */
			!isPermittedModule(msg.sender, msg.sig) &&
			!_checkMultiSig()
		) {
			return false;
		}
		_token.transferCustodian([_from, _to], _value);
		/* bytes4 signature for custodian module internalTransfer() */
		require(_callModules(
			0x44a29e2a,
			0x00,
			abi.encode(_token, _from, _to, _value)
		));
		emit TransferOwnership(_token, _from, _to, _value);
		return true;
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
		IBaseModule _module
	)
		external
		returns (bool)
	{
		if (!_checkMultiSig()) return false;
		require(_module.getOwner() == address(this), "dev: wrong owner");
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
		} else {
			/* msg.sig = 0xbb2a8522 */
			require(isPermittedModule(msg.sender, msg.sig));
		}
		_detachModule(_module);
		return true;
	}

}
