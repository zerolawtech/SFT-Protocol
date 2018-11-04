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

	event NewSecurityToken(address creator, address contractAddr, bytes32 id);
	event Transfer(address indexed from, address indexed to, uint tokens);
	event Approval(address indexed tokenOwner, address indexed spender, uint tokens);
	event BalanceChanged(address indexed owner, uint256 oldBalance, uint256 newBalance);

	/// @notice Security token constructor
	/// @dev Initially the total supply is credited to the issuer
	/// @param _name Name of the token
	/// @param _symbol Unique ticker symbol
	/// @param _totalSupply Total supply of the token
	constructor(address _issuer, string _name, string _symbol, uint256 _totalSupply) public {
		issuer = IssuingEntity(_issuer);
		issuerID = issuer.issuerID();
		name = _name;
		symbol = _symbol;
		balances[_issuer] = _totalSupply;
		totalSupply = _totalSupply;
		emit NewSecurityToken(msg.sender, address(this), issuerID);
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
		require (_value > 0);
		(bytes32[2] memory _id, uint8[2] memory _rating, uint16[2] memory _country) = issuer.checkTransferView(address(this), _from, _to, _value);
		_checkTransfer(address[2]([_from, _to]), _id[0], _id, _rating, _country, _value);
		return true;
	}


	function _checkToSend(
		address _auth,
		address _from,
		address _to,
		uint256 _value
	)
		internal
		returns
	(
		bytes32 _authId,
		bytes32[2] _id,
		address[2] _addr,
		uint8[2] _rating,
		uint16[2] _country
	) {
		require (_value > 0);
		(_authId, _id, _rating, _country) = issuer.checkTransfer(address(this), _auth, _from, _to, _value);
		_addr = _checkTransfer(address[2]([_from, _to]), _authId, _id, _rating, _country, _value);
		return(_authId, _id, _addr, _rating, _country);
	}

	function _checkTransfer(
		address[2] _addr,
		bytes32 _authId,
		bytes32[2] _id,
		uint8[2] _rating,
		uint16[2] _country,
		uint256 _value
	)
		internal
		view
		returns
	(
		address[2]
	) {
		if (_id[0] == issuerID) {
			_addr[0] = address(issuer);
		}
		if (_id[1] == issuerID) {
			_addr[1] = address(issuer);
		}
		for (uint256 i = 0; i < modules.length; i++) {
			if (address(modules[i].module) != 0 && modules[i].checkTransfer) {
				require(ISTModule(modules[i].module).checkTransfer(_addr, _authId, _id, _rating, _country, _value));
			}
		}
		return (
			_addr
		);
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

	/// @notice ERC-20 transfer standard
	/// @param _to Recipient
	/// @param _value Amount being transferred
	/// @return boolean
	function transfer(address _to, uint256 _value) external returns (bool) {
		(
			bytes32 _authId,
			bytes32[2] memory _id,
			address[2] memory _addr,
			uint8[2] memory _rating,
			uint16[2] memory _country
		) = _checkToSend(msg.sender, msg.sender, _to, _value);
		_transfer(_addr, _id, _rating, _country, _value);
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
			uint8[2] memory _rating,
			uint16[2] memory _country
		) = _checkToSend(_auth, _from, _to, _value);

		if (_id[0] != _id[1] && _authId != issuerID) {
			/*
				If the call was not made by the issuer and involves a change
				in ownership, subtract from the allowed mapping.
			*/
			allowed[_from][_auth] = allowed[_from][_auth].sub(_value);
		}
		_transfer(_addr, _id, _rating, _country, _value);
		return true;
	}

	/// @notice Internal transfer function
	/// @param _addr Array of sender/receiver addresses
	/// @param _id Array of sender/receiver IDs
	/// @param _rating Array of sender/receiver ratings
	/// @param _country Array of sender/receiver countries
	/// @param _value Amount to transfer
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
		require (issuer.transferTokens(_id, _rating, _country, _value));
		for (uint256 i = 0; i < modules.length; i++) {
			if (address(modules[i].module) != 0 && modules[i].transferTokens) {
				require (ISTModule(modules[i].module).transferTokens(_addr, _id, _rating, _country, _value));
			}
		}
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
		(bytes32 _id, uint8 _rating, uint16 _country) = issuer.balanceChanged(_owner, _old, _value);
		for (uint256 i = 0; i < modules.length; i++) {
			if (address(modules[i].module) != 0 && modules[i].balanceChanged) {
				require (ISTModule(modules[i].module).balanceChanged(_owner, _id, _rating, _country, _old, _value));
			}
		}
		emit BalanceChanged(_owner, _old, _value);
		return true;
	}

	function attachModule(address _module) external returns (bool) {
		require(msg.sender == address(issuer));
		_attachModule(_module);
		return true;
	}

	function detachModule(address _module) external returns (bool) {
		if (_module != msg.sender) {
			require(msg.sender == address(issuer));
		}
		_detachModule(_module);
		return true;
	}

	/// @notice Determines if a module is active on this token
	/// @dev If a module is active on the issuer level, it will apply to all tokens
	/// under that issuer
	/// @param _module Deployed module address
	function isActiveModule(address _module) internal view returns (bool) {
		if (activeModules[_module]) return true;
		return issuer.isActiveModule(_module);
	}

}
