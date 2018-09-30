pragma solidity ^0.4.24;

import "./open-zeppelin/SafeMath.sol";
import "./IssuingEntity.sol";
import "./STBase.sol";


contract TokenFactory {

	address registrar;

	constructor(address _registrar) public {
		registrar = _registrar;
	}

	function newToken(
		address _issuer,
		string _name,
		string _symbol,
		uint256 _totalSupply
	)
		external
		returns (address)
	{
		require (msg.sender == registrar);
		return new SecurityToken(_issuer, _name, _symbol, _totalSupply);
	}
}


/// @title Security Token
contract SecurityToken is STBase {

	using SafeMath for uint256;

	IssuingEntity public issuer;

	/* Assets cannot be fractionalized */
	uint8 public constant decimals = 0;
	string public name;
	string public symbol;
	uint256 public totalSupply;

	mapping (address => uint256) balances;
	mapping (address => mapping (address => uint256)) allowed;

	event Transfer(address from, address to, uint tokens);
	event Approval(address tokenOwner, address spender, uint tokens);
	event BalanceChanged(address owner, uint256 oldBalance, uint256 newBalance);

	/// @notice Security token constructor
	/// @dev Initially the total supply is credited to the issuer
	/// @param _name Name of the token
	/// @param _symbol Unique ticker symbol
	/// @param _totalSupply Total supply of the token
	constructor(address _issuer, string _name, string _symbol, uint256 _totalSupply) public {
		issuer = IssuingEntity(_issuer);
		issuerID = issuer.issuerID();
		registrar = KYCRegistrar(issuer.registrar());
		name = _name;
		symbol = _symbol;
		balances[msg.sender] = _totalSupply;
		totalSupply = _totalSupply;
		emit Transfer(0, msg.sender, _totalSupply);
	}

	/// @notice Fetch circulating supply
	/// @dev Circulating supply = total supply - amount retained by issuer
	/// @return integer
	function circulatingSupply() public view returns (uint256) {
		return totalSupply.sub(balanceOf(address(issuer)));
	}

	/// @notice Fetch the amount retained by issuer
	/// @return integer
	function treasurySupply() public view returns (uint256) {
		return balanceOf(address(issuer));
	}

	/// @notice Fetch the current balance at an address
	/// @return integer
	function balanceOf(address _owner) public view returns (uint256) {
		return balances[_owner];
	}

	/// @notice Fetch the allowance
	/// @param _owner Owner of the tokens
	/// @param _spender Spender of the tokens
	/// @return integer
	function allowance(
		address _owner,
		address _spender
	 )
		public
		view
		returns (uint256)
	{
		return allowed[_owner][_spender];
	}

	/// @notice Check if a transfer is possible at the token level
	/// @param _from Sender
	/// @param _to Recipient
	/// @param _value Amount being transferred
	/// @return boolean
	function checkTransfer(
		address _from,
		address _to, 
		uint256 _value
	)
		external
		view
		returns (bool)
	{
		_checkTransfer(_from, _from, _to, _value);
		return true;
	}

	
	function _checkTransfer(
		address _auth,
		address _from,
		address _to,
		uint256 _value
	)
		internal
		returns (bytes32, bytes32[2], address[2])
	{
		require (_value > 0);
		(
			bytes32 _authId,
			bytes32[2] memory _id,
			uint8[2] memory _class,
			uint16[2] memory _country
		) = registrar.checkTransfer(issuerID, address(this), _auth, _from, _to);		
		if (_id[0] == issuerID) {
			_from = address(issuer);
		}
		if (_id[1] == issuerID) {
			_to = address(issuer);
		}
		for (uint256 i = 0; i < modules.length; i++) {
			if (address(modules[i].module) != 0 && modules[i].checkTransfer) {
				require(STModule(modules[i].module).checkTransfer(_from, _to, _value));
			}
		}
		require (issuer.checkTransfer(address(this), _authId, _id, _class, _country, _value));
		return (
			_authId,
			_id,
			address[2]([_from, _to])
		);
	}

	/// @notice ERC-20 transfer standard
	/// @param _to Recipient
	/// @param _value Amount being transferred
	/// @return boolean
	function transfer(address _to, uint256 _value) external onlyUnlocked returns (bool) {
		(
			bytes32 _authId,
			bytes32[2] memory _id,
			address[2] memory _addr
		) = _checkTransfer(msg.sender, msg.sender, _to, _value);
		_transfer(_addr[0], _addr[1], _value);
		return true;
	}

	/// @notice ERC-20 transferFrom standard
	/// @param _from Sender
	/// @param _to Recipient
	/// @param _value Amount being transferred
	/// @return boolean
	function transferFrom(
		address _from,
		address _to,
		uint256 _value
	)
		external
		onlyUnlocked
		returns (bool)
	{
		/* If called by a module, the authority becomes the issuing contract. */
		if (isActiveModule(msg.sender)) {
			address _auth = address(issuer);
		} else {
			_auth = msg.sender;
		}
		(
			bytes32 _authId,
			bytes32[2] memory _id,
			address[2] memory _addr
		) = _checkTransfer(_auth, _from, _to, _value);

		if (_id[0] != _id[1] && _authId != issuerID) {
			/*
				If the call was not made by the issuer and involves a change
				in ownership, subtract from the allowed mapping.
			*/
			allowed[_from][_auth] = allowed[_from][_auth].sub(_value);
		}
		_transfer(_addr[0], _addr[1], _value);
		return true;
	}

	/// @notice Internal transfer function
	/// @param _from Sender
	/// @param _to Recipient
	/// @param _value Amount being transferred
	function _transfer(address _from, address _to, uint256 _value) internal {
		balances[_from] = balances[_from].sub(_value);
		balances[_to] = balances[_to].add(_value);
		for (uint256 i = 0; i < modules.length; i++) {
			if (address(modules[i].module) != 0 && modules[i].transferTokens) {
				require (STModule(modules[i].module).transferTokens(_from, _to, _value));
			}
		}
		require (issuer.transferTokens(address(this), _from, _to, _value));
		emit Transfer(_from, _to, _value);
	}

	/// @notice Directly modify the balance of an account
	/// @notice May be used for minting, redemption, split, dilution, etc
	/// @dev This function is only callable via module
	/// @param _owner Owner of the tokens
	/// @param _value Balance to set
	function modifyBalance(address _owner, uint256 _value) public returns (bool) {
		require (isActiveModule(msg.sender));
		if (balances[_owner] == _value) return true;
		if (balances[_owner] > _value) {
			totalSupply = totalSupply.sub(balances[_owner].sub(_value));
		} else {
			totalSupply = totalSupply.add(_value.sub(balances[_owner]));
		}

		uint256 _old = balances[_owner];
		balances[_owner] = _value;
		for (uint256 i = 0; i < modules.length; i++) {
			if (address(modules[i].module) != 0 && modules[i].balanceChanged) {
				require (STModule(modules[i].module).balanceChanged(_owner, _old, _value));
			}
		}
		require (issuer.balanceChanged(address(this), _owner, _old, _value));
		emit BalanceChanged(_owner, _old, _value);
	}

	/// @notice Determines if a module is active on this token
	/// @dev If a module is active on the issuer level, it will apply to all tokens
	/// under that issuer
	/// @param _module Deployed module address
	function isActiveModule(address _module) internal view returns (bool) {
		if (activeModules[_module]) return true;
		return issuer.isActiveModule(_module);
	}

	function approve(address _spender, uint256 _value) external returns (bool) {
		require (_spender != address(this));
		require (_value == 0 || allowed[msg.sender][_spender] == 0);
		allowed[msg.sender][_spender] = _value;
		emit Approval(msg.sender, _spender, _value);
		return true;
	}


}
