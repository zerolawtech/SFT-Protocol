pragma solidity >=0.4.24 <0.5.0;

import "./Modular.sol";
import "../IssuingEntity.sol";
import "../interfaces/IBaseCustodian.sol";

/**
	@title Security Token Base
	@dev
		Expands upon the ERC20 token standard
		https://theethereum.wiki/w/index.php/ERC20_Token_Standard
 */
contract TokenBase is Modular {

	bytes32 public ownerID;
	IssuingEntity public issuer;

	/* Assets cannot be fractionalized */
	uint8 public constant decimals = 0;
	string public name;
	string public symbol;
	uint256 public totalSupply;
	uint256 public authorizedSupply;

	/* token holder, custodian contract */
	mapping (address => mapping (address => uint256)) custBalances;
	mapping (address => mapping (address => uint256)) allowed;

	event Transfer(address indexed from, address indexed to, uint256 tokens);
	event Approval(
		address indexed tokenOwner,
		address indexed spender,
		uint256 tokens
	);
	event AuthorizedSupplyChanged(uint256 oldAuthorized, uint256 newAuthorized);

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
	{
		issuer = _issuer;
		ownerID = _issuer.ownerID();
		name = _name;
		symbol = _symbol;
		authorizedSupply = _authorizedSupply;
	}

	/**
		@notice Fetch circulating supply
		@dev Circulating supply = total supply - amount retained by issuer
		@return integer
	 */
	function circulatingSupply() external view returns (uint256) {
		return totalSupply - balanceOf(address(issuer));
	}

	/**
		@notice Fetch the amount retained by issuer
		@return integer
	 */
	function treasurySupply() external view returns (uint256) {
		return balanceOf(address(issuer));
	}

	/**
		@dev Implemented in inheriting contracts
	 */
	function balanceOf(address) public view returns (uint256);

	/**
		@notice Fetch the current balance at an address within a given custodian
		@param _owner Address of balance to query
		@param _cust Custodian contract address
		@return integer
	 */
	function custodianBalanceOf(
		address _owner,
		address _cust
	)
		external
		view
		returns (uint256)
	{
		return custBalances[_owner][_cust];
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
		@notice Check if a transfer is permitted
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
		_checkTransferView(0x00, _from, _to, _value, _value == balanceOf(_from));
		return true;
	}

	/**
		@notice Check if a custodian internal transfer is permitted
		@dev If a transfer is not allowed, the function will throw
		@param _cust Address of custodian contract
		@param _from Address of sender
		@param _to Address of recipient
		@param _value Amount being transferred
		@return bool success
	 */
	function checkTransferCustodian(
		address _cust,
		address _from,
		address _to,
		uint256 _value
	)
		external
		view
		returns (bool)
	{
		_checkTransferView(
			_cust,
			_from,
			_to,
			_value,
			_value == custBalances[_from][_cust]
		);
		return true;
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
	) internal;

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
		@notice Modify authorized Supply
		@dev Callable by issuer or via module
		@param _value New authorized supply value
		@return bool
	 */
	function modifyAuthorizedSupply(uint256 _value) external returns (bool) {
		/* msg.sig = 0xc39f42ed */
		if (!_checkPermitted()) return false;
		require(_value >= totalSupply, "dev: auth below total");
		/* bytes4 signature for token module modifyAuthorizedSupply() */
		require(_callModules(
			0xa5f502c1,
			0x00,
			abi.encode(authorizedSupply, _value)
		));
		emit AuthorizedSupplyChanged(authorizedSupply, _value);
		authorizedSupply = _value;
		return true;
	}

	/**
		@notice Internal shared logic for minting and burning
		@param _owner Owner of the tokens
		@param _old Previous balance
		@return bool success
	 */
	function _modifyTotalSupply(
		address _owner,
		uint256 _old
	)
		internal
		returns (bool)
	{
		uint256 _new = balanceOf(_owner);
		(
			bytes32 _id,
			uint8 _rating,
			uint16 _country
		) = issuer.modifyTokenTotalSupply(_owner, _old, _new);
		/* bytes4 signature for token module totalSupplyChanged() */
		require(_callModules(
			0x741b5078,
			0x00,
			abi.encode(_owner, _id, _rating, _country, _old, _new)
		));
		return true;
	}

	/**
		@notice Attach a security token module
		@dev Can only be called indirectly from IssuingEntity.attachModule()
		@param _module Address of the module contract
		@return bool success
	 */
	function attachModule(address _module) external returns (bool) {
		require(msg.sender == address(issuer), "dev: only issuer");
		_attachModule(_module);
		return true;
	}

	/**
		@notice Detach a security token module
		@dev
			Called indirectly from IssuingEntity.attachModule() or by the
			module that is attached.
		@param _module Address of the module contract
		@return bool success
	 */
	function detachModule(address _module) external returns (bool) {
		if (_module != msg.sender) {
			require(msg.sender == address(issuer), "dev: only issuer");
		} else {
			/* msg.sig = 0xbb2a8522 */
			require(isPermittedModule(msg.sender, msg.sig));
		}
		_detachModule(_module);
		return true;
	}

	/**
		@notice Checks that a call comes from a permitted module or the issuer
		@dev If the caller is the issuer, requires multisig approval
		@return bool multisig approved
	 */
	function _checkPermitted() internal returns (bool) {
		if (isPermittedModule(msg.sender, msg.sig)) return true;
		return issuer.checkMultiSigExternal(
			msg.sender,
			keccak256(msg.data),
			msg.sig
		);
	}

}
