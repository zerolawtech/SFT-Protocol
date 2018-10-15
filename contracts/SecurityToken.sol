pragma solidity ^0.4.24;

import "./open-zeppelin/SafeMath.sol";
import "./IssuingEntity.sol";
import "./STBase.sol";


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
		balances[_issuer] = _totalSupply;
		totalSupply = _totalSupply;
		emit Transfer(0, _issuer, _totalSupply);
	}

	/// @notice Fetch circulating supply
	/// @dev Circulating supply = total supply - amount retained by issuer
	/// @return integer
	function circulatingSupply() external view returns (uint256) {
		return totalSupply.sub(balances[address(issuer)]);
	}

	/// @notice Fetch the amount retained by issuer
	/// @return integer
	function treasurySupply() external view returns (uint256) {
		return balances[address(issuer)];
	}

	/// @notice Fetch the current balance at an address
	/// @return integer
	function balanceOf(address _owner) external view returns (uint256) {
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
		external
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
		view
		returns (
			bytes32 _authId,
			bytes32[2] _id,
			address[2] _addr,
			uint8[2] _class,
			uint16[2] _country
		)
	{
		require (_value > 0);
		(
			_authId,
			_id,
			_class,
			_country
		) = registrar.checkTransfer(issuerID, _auth, _from, _to);		
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
			address[2]([_from, _to]),
			_class,
			_country
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
			address[2] memory _addr,
			uint8[2] memory _class,
			uint16[2] memory _country
		) = _checkTransfer(msg.sender, msg.sender, _to, _value);
		_transfer(_addr, _id, _class, _country, _value);
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
			address[2] memory _addr,
			uint8[2] memory _class,
			uint16[2] memory _country
		) = _checkTransfer(_auth, _from, _to, _value);

		if (_id[0] != _id[1] && _authId != issuerID) {
			/*
				If the call was not made by the issuer and involves a change
				in ownership, subtract from the allowed mapping.
			*/
			allowed[_from][_auth] = allowed[_from][_auth].sub(_value);
		}
		_transfer(_addr, _id, _class, _country, _value);
		return true;
	}

	/// @notice Internal transfer function
	/// @param _addr Array of sender/receiver addresses
	/// @param _id Array of sender/receiver IDs
	/// @param _class Array of sender/receiver classes
	/// @param _country Array of sender/receiver countries
	/// @param _value Amount to transfer
	function _transfer(
		address[2] _addr,
		bytes32[2] _id,
		uint8[2] _class,
		uint16[2] _country,		
		uint256 _value
	)
		internal
	{
		balances[_addr[0]] = balances[_addr[0]].sub(_value);
		balances[_addr[1]] = balances[_addr[1]].add(_value);
		for (uint256 i = 0; i < modules.length; i++) {
			if (address(modules[i].module) != 0 && modules[i].transferTokens) {
				require (STModule(modules[i].module).transferTokens(_addr[0], _addr[1], _value));
			}
		}
		require (issuer.transferTokens(_id, _class, _country, _value));
		emit Transfer(_addr[0], _addr[1], _value);
	}

	/// @notice Directly modify the balance of an account
	/// @notice May be used for minting, redemption, split, dilution, etc
	/// @dev This function is only callable via module
	/// @param _owner Owner of the tokens
	/// @param _value Balance to set
	/// @return bool
	function modifyBalance(address _owner, uint256 _value) external returns (bool) {
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
		require (issuer.balanceChanged(_owner, _old, _value));
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

	/// @notice ERC-20 approve standard
	/// @param _spender Address being approved to transfer tokens
	/// @param _value Amount approved for transfer
	/// @return boolean
	function approve(address _spender, uint256 _value) external returns (bool) {
		require (_spender != address(this));
		require (_value == 0 || allowed[msg.sender][_spender] == 0);
		allowed[msg.sender][_spender] = _value;
		emit Approval(msg.sender, _spender, _value);
		return true;
	}


}
