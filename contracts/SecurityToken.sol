pragma solidity >=0.4.24 <0.5.0;

import "./open-zeppelin/SafeMath.sol";
import "./bases/Token.sol";

/**
	@title Security Token
	@dev
		Expands upon the ERC20 token standard
		https://theethereum.wiki/w/index.php/ERC20_Token_Standard
 */
contract SecurityToken is TokenBase {

	using SafeMath for uint256;

	mapping (address => uint256) balances;

	/**
		@notice Security token constructor
		@dev Initially the total supply is credited to the issuer
		@param _issuer Address of the issuer's IssuingEntity contract
		@param _name Name of the token
		@param _symbol Unique ticker symbol
		@param _authorizedSupply Initial authorized token supply
	 */
	constructor(
		IssuingEntity _issuer,
		string _name,
		string _symbol,
		uint256 _authorizedSupply
	)
		public
		TokenBase(
			_issuer,
			_name,
			_symbol,
			_authorizedSupply
		)
	{
		return;
	}

	/**
		@notice Fetch the current balance at an address
		@param _owner Address of balance to query
		@return integer
	 */
	function balanceOf(address _owner) public view returns (uint256) {
		return balances[_owner];
	}

	/**
		@notice shared logic for checkTransfer and checkTransferCustodian
		@dev If a transfer is not allowed, the function will throw
		@param _cust Address of custodian contract
		@param _from Address of sender
		@param _to Address of recipient
		@param _value Amount being transferred,
		@param _zero After transfer, does the sender have a 0 balance?
	 */
	function _checkTransferView(
		address _cust,
		address _from,
		address _to,
		uint256 _value,
		bool _zero
	)
		internal
	{
		(
			bytes32 _authID,
			bytes32[2] memory _id,
			uint8[2] memory _rating,
			uint16[2] memory _country
		) = issuer.checkTransfer(_from, _from, _to, _zero);
		_checkTransfer(
			_authID,
			_id,
			_cust,
			[_from, _to],
			_rating,
			_country,
			_value
		);
	}

	/**
		@notice internal check of transfer permission
		@dev
			seperate from _checkTransferView so it can be called by transfer
			related functions without the call to issuer.checkTransfer
		@param _authID ID of caller
		@param _id ID array of investor IDs
		@param _cust Custodian address (0x00 if none)
		@param _addr address array of investors
		@param _rating array of investor ratings
		@param _country array of investor countries
		@param _value Amount being transferred
		@return array of investor addresses
	 */
	function _checkTransfer(
		bytes32 _authID,
		bytes32[2] _id,
		address _cust,
		address[2] _addr,
		uint8[2] _rating,
		uint16[2] _country,
		uint256 _value
	)
		internal
		view
		returns (address[2])
	{
		require(_value > 0, "Cannot send 0 tokens");
		/* Issuer tokens are held at the IssuingEntity contract address */
		if (_id[0] == ownerID) {
			_addr[0] = address(issuer);
		}
		if (_id[1] == ownerID) {
			_addr[1] = address(issuer);
		}
		if (_cust != 0x00) {
			/**
				if transfer originates from custodian, check custodial balance
				of receiver. Otherwise check custodial balance of sender
			*/
			address _owner = (_addr[0] == _cust ? _addr[1] : _addr[0]);
			require(
				custBalances[_owner][_cust] >= _value,
				"Insufficient Custodial Balance"
			);
		} else {
			require(balances[_addr[0]] >= _value, "Insufficient Balance");
		}

		/* bytes4 signature for token module checkTransfer() */
		require(_callModules(
			0x70aaf928,
			0x00,
			abi.encode(_addr, _authID, _id, _rating, _country, _value)
		));
		return _addr;
	}

	/**
		@notice ERC-20 transfer standard
		@dev calls to _checkToSend() to verify permission before transferring
		@param _to Recipient
		@param _value Amount being transferred
		@return bool success
	 */
	function transfer(address _to, uint256 _value) external returns (bool) {
		_transfer(msg.sender, [msg.sender, _to], _value);
		return true;
	}

	/**
		@notice ERC-20 transferFrom standard
		@dev
			* The issuer may use this function to transfer tokens belonging to
			  any address.
			* Modules may call this function to transfer tokens with the same
			  level of authority as the issuer.
			* An investor with multiple addresses may use this to transfer tokens
			  from any address he controls, without giving prior approval to that
			  address.
			* An unregistered address cannot initiate a transfer, even if it was
			  given approval.
		@param _from Sender
		@param _to Recipient
		@param _value Amount being transferred
		@return bool success
	 */
	function transferFrom(
		address _from,
		address _to,
		uint256 _value
	)
		external
		returns (bool)
	{
		/* If called by a module, the authority becomes the issuing contract. */
		/* msg.sig = 0x23b872dd */
		if (isPermittedModule(msg.sender, msg.sig)) {
			address _auth = address(issuer);
		} else {
			_auth = msg.sender;
		}
		_transfer(_auth, [_from, _to], _value);
		return true;
	}

	/**
		@notice Internal transfer function
		@dev common logic for transfer() and transferFrom()
		@param _auth Address that called the method
		@param _addr Array of receiver/sender address
		@param _value Amount to transfer
	 */
	function _transfer(
		address _auth,
		address[2] _addr,
		uint256 _value
	)
		internal
	{
		(
			bytes32 _authID,
			bytes32[2] memory _id,
			uint8[2] memory _rating,
			uint16[2] memory _country
		) = issuer.transferTokens(
			_auth,
			_addr[0],
			_addr[1],
			/*
				Must send regular and custodial zero balances, as we do not
				yet know which type of transfer this.
			*/
			[
				balances[_addr[0]] == _value,
				balances[_addr[1]] == 0,
				custBalances[_addr[1]][_addr[0]] == _value,
				custBalances[_addr[0]][_addr[1]] == 0
			]
		);
		_addr = _checkTransfer(
			_authID,
			_id,
			/** is sender a custodian? */
			(_rating[0] == 0 && _id[0] != ownerID) ? _addr[0] : 0x00,
			_addr,
			_rating,
			_country,
			_value
		);

		if (_authID != _id[0] && _id[0] != _id[1] && _authID != ownerID) {
			/*
				If the call was not made by the issuer or the sender and involves
				a change in ownership, subtract from the allowed mapping.
			*/
			require(allowed[_addr[0]][_auth] >= _value, "Insufficient allowance");
			allowed[_addr[0]][_auth] = allowed[_addr[0]][_auth].sub(_value);
		}

		/*
			balances are modified regardless of if the transfer involves a
			custodian, to keep sum of balance mapping == totalSupply
		 */
		balances[_addr[0]] = balances[_addr[0]].sub(_value);
		balances[_addr[1]] = balances[_addr[1]].add(_value);

		if (_rating[0] == 0 && _id[0] != ownerID) {
			/* sender is custodian, reduce custodian balance */
			custBalances[_addr[1]][_addr[0]] = custBalances[_addr[1]][_addr[0]].sub(_value);
		}

		if (_rating[1] == 0 && _id[1] != ownerID) {
			/* receiver is custodian, increase custodian balance and notify */
			custBalances[_addr[0]][_addr[1]] = custBalances[_addr[0]][_addr[1]].add(_value);
			require(IBaseCustodian(_addr[1]).receiveTransfer(_addr[0], _value));
		}

		/* bytes4 signature for token module transferTokens() */
		require(_callModules(
			0x35a341da,
			0x00,
			abi.encode(_addr, _id, _rating, _country, _value)
		));
		emit Transfer(_addr[0], _addr[1], _value);
	}

	/**
		@notice Custodian transfer function
		@dev
			called by Custodian.transferInternal to change ownership within
			the custodian contract without moving any tokens
		@param _addr Sender/Receiver addresses
		@param _value Amount to transfer
		@return bool
	 */
	function transferCustodian(
		address[2] _addr,
		uint256 _value
	)
		public
		returns (bool)
	{
		/*
			transfer is presented to issuer.transferTokens as a normal one so
			zero[2:] can be set to false. set here to prevent stack depth error.
		*/
		bool[4] memory _zero = [
			custBalances[_addr[0]][msg.sender] == _value,
			custBalances[_addr[1]][msg.sender] == 0,
			false,
			false
		];
		(
			bytes32 _authID,
			bytes32[2] memory _id,
			uint8[2] memory _rating,
			uint16[2] memory _country
		) = issuer.transferTokens(msg.sender, _addr[0], _addr[1], _zero);

		_addr = _checkTransfer(
			_authID,
			_id,
			msg.sender,
			_addr,
			_rating,
			_country,
			_value
		);
		custBalances[_addr[0]][msg.sender] = custBalances[_addr[0]][msg.sender].sub(_value);
		custBalances[_addr[1]][msg.sender] = custBalances[_addr[1]][msg.sender].add(_value);
		/* bytes4 signature for token module transferTokensCustodian() */
		require(_callModules(
			0x8b5f1240,
			0x00,
			abi.encode(msg.sender, _addr, _id, _rating, _country, _value)
		));
		return true;
	}

	/**
		@notice Mint new tokens and increase total supply
		@dev Callable by the issuer or via module
		@param _owner Owner of the tokens
		@param _value Number of tokens to mint
		@return bool
	 */
	function mint(address _owner, uint256 _value) external returns (bool) {
		/* msg.sig = 0x40c10f19 */
		if (!_checkPermitted()) return false;
		require(_value > 0, "dev: mint 0");
		issuer.checkTransfer(
			address(issuer),
			address(issuer),
			_owner,
			false
		);
		uint256 _old = balances[_owner];
		balances[_owner] = _old.add(_value);
		totalSupply = totalSupply.add(_value);
		require(totalSupply <= authorizedSupply, "dev: exceed auth");
		emit Transfer(0x00, _owner, _value);
		return _modifyTotalSupply(_owner, _old);
	}

	/**
		@notice Burn tokens and decrease total supply
		@dev Callable by the issuer or via module
		@param _owner Owner of the tokens
		@param _value Number of tokens to burn
		@return bool
	 */
	function burn(address _owner, uint256 _value) external returns (bool) {
		/* msg.sig = 0x9dc29fac */
		if (!_checkPermitted()) return false;
		require(_value > 0, "dev: burn 0");
		uint256 _old = balances[_owner];
		balances[_owner] = _old.sub(_value);
		totalSupply = totalSupply.sub(_value);
		emit Transfer(_owner, 0x00, _value);
		return _modifyTotalSupply(_owner, _old);
	}

}
