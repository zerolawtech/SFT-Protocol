pragma solidity >=0.4.24 <0.5.0;

import "./open-zeppelin/SafeMath.sol";
import "./IssuingEntity.sol";
import "./components/Modular.sol";

/**
	@title Security Token
	@dev
		Expands upon the ERC20 token standard
		https://theethereum.wiki/w/index.php/ERC20_Token_Standard
 */
contract SecurityToken is Modular {

	using SafeMath for uint256;

	bytes32 public ownerID;
	IssuingEntity public issuer;

	/* Assets cannot be fractionalized */
	uint8 public constant decimals = 0;
	string public name;
	string public symbol;
	uint256 public totalSupply;

	mapping (address => uint256) balances;
	mapping (address => mapping (address => uint256)) allowed;

	event Transfer(address indexed from, address indexed to, uint tokens);
	event Approval(
		address indexed tokenOwner,
		address indexed spender,
		uint tokens
	);
	event BalanceChanged(
		address indexed owner,
		uint256 oldBalance,
		uint256 newBalance
	);

	/**
		@notice Security token constructor
		@dev Initially the total supply is credited to the issuer
		@param _issuer Address of the issuer's IssuingEntity contract
		@param _name Name of the token
		@param _symbol Unique ticker symbol
		@param _totalSupply Total supply of the token
	 */
	constructor(
		address _issuer,
		string _name,
		string _symbol,
		uint256 _totalSupply
	)
		public
	{
		issuer = IssuingEntity(_issuer);
		ownerID = issuer.ownerID();
		name = _name;
		symbol = _symbol;
		balances[_issuer] = _totalSupply;
		totalSupply = _totalSupply;
		emit Transfer(0, _issuer, _totalSupply);
	}

	/**
		@notice Fetch circulating supply
		@dev Circulating supply = total supply - amount retained by issuer
		@return integer
	 */
	function circulatingSupply() external view returns (uint256) {
		return totalSupply.sub(balances[address(issuer)]);
	}

	/**
		@notice Fetch the amount retained by issuer
		@return integer
	 */
	function treasurySupply() external view returns (uint256) {
		return balances[address(issuer)];
	}

	/**
		@notice Fetch the current balance at an address
		@param _owner Address of balance to query
		@return integer
	 */
	function balanceOf(address _owner) external view returns (uint256) {
		return balances[_owner];
	}

	/**
		@notice Fetch the allowance
		@param _owner Owner of the tokens
		@param _spender Spender of the tokens
		@return integer
	 */
	function allowance(
		address _owner,
		address _spender
	 )
		external
		view
		returns (uint256)
	{
		return allowed[_owner][_spender];
	}

	/**
		@notice View function to check if a transfer is permitted
		@dev If a transfer is not allowed, the function will throw
		@param _from Address of sender
		@param _to Address of recipient
		@param _value Amount being transferred
		@return bool success
	 */
	function checkTransfer(
		address _from,
		address _to, 
		uint256 _value
	)
		external
		view
		returns (bool)
	{
		/* Sending 0 balance is blocked to reduce logic around investor limits */
		require(_value > 0, "Cannot send 0 tokens");
		(
			bytes32 _authID,
			bytes32[2] memory _id,
			uint8[2] memory _rating,
			uint16[2] memory _country
		) = issuer.checkTransfer(
			address(this),
			_from,
			_from,
			_to,
			_value == balances[_from],
			_value
		);
		_checkTransfer([_from, _to], _id[0], _id, _rating, _country, _value);
		return true;
	}

	/**
		@notice Check if custodian internal transfer is permitted
		@dev If a transfer is not allowed, the function will throw
		@dev Do not call directly, use Custodian.checkTransferInternal
		@param _id Array of sender/receiver investor IDs
		@param _stillOwner bool is sender still a beneficial owner?
		@return bool success
	 */
	function checkTransferCustodian(
		bytes32[2] _id,
		bool _stillOwner
	)
		external
		view
		returns (bool)
	{
		(
			bytes32 _custID,
			uint8[2] memory _rating,
			uint16[2] memory _country
		) = issuer.checkTransferCustodian(
			msg.sender,
			address(this),
			_id,
			_stillOwner
		);
		_checkTransfer(
			[address(0), address(0)],
			_custID,
			_id,
			_rating,
			_country,
			0
		);
		return true;
	}

	/**
		@notice internal check of transfer permission before performing it
		@param _auth Address calling to initiate the transfer
		@param _from Address of sender
		@param _to Address of recipient
		@param _value Amount being transferred
		@return ID of caller
		@return ID array of investors
		@return address array of investors 
		@return uint8 array of investor ratings
		@return uint16 array of investor countries
	 */
	function _checkToSend(
		address _auth,
		address _from,
		address _to,
		uint256 _value
	)
		internal
		returns (
			bytes32 _authID,
			bytes32[2] _id,
			address[2] _addr,
			uint8[2] _rating,
			uint16[2] _country
		)
	{
		require(_value > 0, "Cannot send 0 tokens");
		(_authID, _id, _rating, _country) = issuer.checkTransfer(
			address(this),
			_auth,
			_from,
			_to,
			_value == balances[_from],
			_value
		);
		_addr = _checkTransfer(
			[_from, _to],
			_authID,
			_id,
			_rating,
			_country,
			_value
		);
		return(_authID, _id, _addr, _rating, _country);
	}

	/**
		@notice internal check of transfer permission
		@dev common logic for checkTransfer() and _checkToSend()
		@param _addr address array of investors 
		@param _authID ID of caller
		@param _id ID array of investor IDs
		@param _rating array of investor ratings
		@param _country array of investor countries
		@param _value Amount being transferred
		@return array of investor addresses
	 */
	function _checkTransfer(
		address[2] _addr,
		bytes32 _authID,
		bytes32[2] _id,
		uint8[2] _rating,
		uint16[2] _country,
		uint256 _value
	)
		internal
		view
		returns (address[2])
	{
		/* Issuer tokens are held at the IssuingEntity contract address */
		if (_id[0] == ownerID) {
			_addr[0] = address(issuer);
		}
		if (_id[1] == ownerID) {
			_addr[1] = address(issuer);
		}
		require(balances[_addr[0]] >= _value, "Insufficient Balance");
		/* bytes4 signature for token module checkTransfer() */
		_callModules(0x70aaf928, abi.encode(
			_addr,
			_authID,
			_id,
			_rating,
			_country,
			_value
		));
		return _addr;
	}

	/**
		@notice ERC-20 approve standard
		@dev
			Approval may be given to addresses that are not registered,
			but the address will not be able to call transferFrom()
		@param _spender Address being approved to transfer tokens
		@param _value Amount approved for transfer
		@return bool success
	 */
	function approve(address _spender, uint256 _value) external returns (bool) {
		require(_spender != address(this));
		require(_value == 0 || allowed[msg.sender][_spender] == 0);
		allowed[msg.sender][_spender] = _value;
		emit Approval(msg.sender, _spender, _value);
		return true;
	}

	/**
		@notice ERC-20 transfer standard
		@dev calls to _checkToSend() to verify permission before transferring
		@param _to Recipient
		@param _value Amount being transferred
		@return bool success
	 */
	function transfer(address _to, uint256 _value) external returns (bool) {
		(
			bytes32 _authID,
			bytes32[2] memory _id,
			address[2] memory _addr,
			uint8[2] memory _rating,
			uint16[2] memory _country
		) = _checkToSend(msg.sender, msg.sender, _to, _value);
		_transfer(_addr, _id, _rating, _country, _value);
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
        if (isPermittedModule(msg.sender, msg.sig)) {
			address _auth = address(issuer);
		} else {
			_auth = msg.sender;
		}
		(
			bytes32 _authID,
			bytes32[2] memory _id,
			address[2] memory _addr,
			uint8[2] memory _rating,
			uint16[2] memory _country
		) = _checkToSend(_auth, _from, _to, _value);

		if (_id[0] != _id[1] && _authID != ownerID && _authID != _id[0]) {
			/*
				If the call was not made by the issuer or the sender and involves
				a change in ownership, subtract from the allowed mapping.
			*/
			require(allowed[_from][_auth] >= _value, "Insufficient allowance");
			allowed[_from][_auth] = allowed[_from][_auth].sub(_value);
		}
		_transfer(_addr, _id, _rating, _country, _value);
		return true;
	}

	/**
		@notice Internal transfer function
		@dev common logic for transfer() and transferFrom()
		@param _addr Array of sender/receiver addresses
		@param _id Array of sender/receiver IDs
		@param _rating Array of sender/receiver ratings
		@param _country Array of sender/receiver countries
		@param _value Amount to transfer
	 */
	function _transfer(
		address[2] _addr,
		bytes32[2] _id,
		uint8[2] _rating,
		uint16[2] _country,		
		uint256 _value
	)
		internal
	{
		balances[_addr[0]] = balances[_addr[0]].sub(_value);
		balances[_addr[1]] = balances[_addr[1]].add(_value);
		require(issuer.transferTokens(
			_id,
			_rating,
			_country,
			_value,
			[balances[_addr[0]] == 0, balances[_addr[1]] == _value]
		));
		/* bytes4 signature for token module transferTokens() */
		_callModules(
			0x35a341da,
			abi.encode(_addr, _id, _rating, _country, _value)
		);
		emit Transfer(_addr[0], _addr[1], _value);
	}

	/**
		@notice Check custodian internal transfer permission and set ownership
		@dev Called by Custodian.transferInternal
		@param _id Array of sender/receiver investor IDs
		@param _value Amount being transferred
		@param _stillOwner bool is sender still a beneficial owner?
		@return bool success
	 */
	function transferCustodian(
		bytes32[2] _id,
		uint256 _value,
		bool _stillOwner
	)
		external
		returns (bool)
	{
		(
			bytes32 _custID,
			uint8[2] memory _rating,
			uint16[2] memory _country
		) = issuer.checkTransferCustodian(
			msg.sender,
			address(this),
			_id,
			_stillOwner
		);
		_checkTransfer(
			[address(0), address(0)],
			_custID,
			_id,
			_rating,
			_country,
			0
		);
		require(issuer.transferCustodian(
			_custID,
			_id,
			_rating,
			_country,
			_value,
			_stillOwner
		));
		/* bytes4 signature for token module transferTokensCustodian() */
		_callModules(
			0x4f072579,
			abi.encode(msg.sender, _id, _rating, _country, _value)
		);
		return true;
	}

	/**
		@notice Directly modify the balance of an account
		@notice May be used for minting, redemption, split, dilution, etc
		@dev This function is only callable via module
		@param _owner Owner of the tokens
		@param _value Balance to set
		@return bool
	 */
	function modifyBalance(
		address _owner,
		uint256 _value
	)
		external
		returns (bool)
	{
        require(isPermittedModule(msg.sender, msg.sig));
		if (balances[_owner] == _value) return true;
		if (balances[_owner] > _value) {
			totalSupply = totalSupply.sub(balances[_owner].sub(_value));
		} else {
			totalSupply = totalSupply.add(_value.sub(balances[_owner]));
		}
		uint256 _old = balances[_owner];
		balances[_owner] = _value;
		(
			bytes32 _id,
			uint8 _rating,
			uint16 _country
		) = issuer.modifyBalance(_owner, _old, _value);
		/* bytes4 signature for token module balanceChanged() */
		_callModules(
			0x4268353d,
			abi.encode(_owner, _id, _rating, _country, _old, _value)
		);
		emit BalanceChanged(_owner, _old, _value);
		return true;
	}

	/**
		@notice Attach a security token module
		@dev Can only be called indirectly from IssuingEntity.attachModule()
		@param _module Address of the module contract
		@return bool success
	 */
	function attachModule(address _module) external returns (bool) {
		require(msg.sender == address(issuer));
		_attachModule(_module);
		return true;
	}

	/**
		@notice Attach a security token module
		@dev
			Called indirectly from IssuingEntity.attachModule() or by the
			module that is attached.
		@param _module Address of the module contract
		@return bool success
	 */
	function detachModule(address _module) external returns (bool) {
		if (_module != msg.sender) {
			require(msg.sender == address(issuer));
		} else {
            require(isPermittedModule(msg.sender, msg.sig));
        }
		_detachModule(_module);
		return true;
	}

	/**
		@notice Check if a module is active on this token
		@dev
			IssuingEntity modules are considered active on all tokens associated
			with that issuer.
		@param _module Deployed module address
	 */
	function isActiveModule(address _module) public view returns (bool) {
		if (modulePermissions[_module].active) return true;
		return issuer.isActiveModule(_module);
	}

    function isPermittedModule(address _module, bytes4 _sig) public view returns (bool) {
		if (
			modulePermissions[_module].active && 
			modulePermissions[_module].permissions[_sig][1]
		) {
            return true;
        }
        return issuer.isPermittedModule(_module, _sig);
	}

}
