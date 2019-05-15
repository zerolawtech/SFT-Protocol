pragma solidity >=0.4.24 <0.5.0;

import "../../open-zeppelin/SafeMath.sol";
import "./Module.sol";

/**
	@title Checkpoint Module Base Contract
	@dev Inherited contract for token modules requiring a balance checkpoint
*/
contract CheckpointModuleBase is STModuleBase {

	using SafeMath for uint256;

	uint256 totalSupply;
	uint256 public checkpointTime;

	mapping (address => uint256) balances;
	mapping (address => bool) zeroBalances;

	/* token holder, custodian contract */
	mapping (address => mapping(address => uint256)) custBalances;
	mapping (address => mapping(address => bool)) custZeroBalances;

	/**
		@notice Base constructor
		@param _token SecurityToken contract address
		@param _issuer IssuingEntity contract address
		@param _checkpointTime Epoch time of balance checkpoint
	 */
	constructor(
		SecurityToken _token,
		address _issuer,
		uint256 _checkpointTime
	)
		STModuleBase(_token, _issuer)
		public
	{
		require (_checkpointTime >= now);
		totalSupply = token.totalSupply();
		checkpointTime = _checkpointTime;
	}

	/**
		@notice supply permissions and hook points when attaching module
		@dev
			permissions: 0xbb2a8522 - detachModule
			hooks: 0x35a341da - transferTokens
				   0x8b5f1240 - transferTokensCustodian
				   0x741b5078 - totalSupplyChanged
			hookBools - all true
	 */
	function getPermissions()
		external
		pure
		returns
	(
		bytes4[] permissions,
		bytes4[] hooks,
		uint256 hookBools
	)
	{
		permissions = new bytes4[](1);
		permissions[0] = 0xbb2a8522;
		
		hooks = new bytes4[](3);
		hooks[0] = 0x35a341da;
		hooks[1] = 0x8b5f1240;
		hooks[2] = 0x741b5078;
		
		return (permissions, hooks, ~uint256(0));
	}

	/**
		@notice Internal getter for inherited contract to query checkpoint balance
		@dev Should only be called when now > time
		@param _owner Address of balance to query
		@return uint256 balance
	 */
	function _getBalance(address _owner) internal view returns (uint256) {
		if (balances[_owner] > 0) return balances[_owner];
		if (zeroBalances[_owner]) return 0;
		return token.balanceOf(_owner);
	}

	/**
		@notice Getter, Inherited contract query custodied checkpoint balance
		@dev Should only be called when now > time
		@param _owner Address of balance to query
		@param _cust Custodian address
		@return uint256 balance
	 */
	function _getCustodianBalance(
		address _owner,
		address _cust
	)
		internal
		view
		returns (uint256)
	{
		if (custBalances[_owner][_cust] > 0) return custBalances[_owner][_cust];
		if (custZeroBalances[_owner][_cust]) return 0;
		return token.custodianBalanceOf(_owner, _cust);
	}

	/**
		@notice Check if a checkpoint balance has been stored
		@param _owner Address to check
		@return bool
	 */
	function _isBalanceSet(address _owner) private view returns (bool) {
		return (balances[_owner] > 0 || zeroBalances[_owner]);
	}

	/**
		@notice Store a checkpoint balance
		@param _owner Address to set
		@param _value Balance at address
	 */
	function _setBalance(address _owner, uint256 _value) private {
		if (_value == 0) {
			zeroBalances[_owner] = true;
		} else {
			balances[_owner] = _value;
		}
	}

	/**
		@notice Store custodian checkpoint balance after tokens are sent
		@param _owner Address of owner
		@param _cust Address of custodian
		@param _value Amount transferred
	 */
	function _custodianSent(
		address _owner,
		address _cust,
		uint256 _value
	)
		private
	{
		if (
			custBalances[_owner][_cust] > 0 ||
			custZeroBalances[_owner][_cust]
		) return;
		_value = token.custodianBalanceOf(_owner, _cust).add(_value);
		custBalances[_owner][_cust] = _value;
	}

	/**
		@notice Store custodian checkpoint balance after tokens are received
		@param _owner Address of owner
		@param _cust Address of custodian
		@param _value Amount transferred
	 */
	function _custodianReceived(
		address _owner,
		address _cust,
		uint256 _value
	)
		private
	{
		if (
			custBalances[_owner][_cust] > 0 ||
			custZeroBalances[_owner][_cust]
		) return;
		uint256 _bal = token.custodianBalanceOf(_owner, _cust).sub(_value);
		if (_bal == 0) {
			custZeroBalances[_owner][_cust] == true;
		} else {
			custBalances[_owner][_cust] = _bal;
		}
	}

	/**
		@notice Hook method, record checkpoint value after a transfer
		@param _addr Sender/receiver address
		@param _id Sender/receiver investor ID
		@param _rating Sender/receiver rating
		@param _value Amount transferred
		@return bool
	 */
	function transferTokens(
		address[2] _addr,
		bytes32[2] _id,
		uint8[2] _rating,
		uint16[2],
		uint256 _value
	)
		external
		returns (bool)
	{
		require(msg.sender == address(token));
		if (now < checkpointTime) return true;
		if (_rating[0] == 0 && _id[0] != ownerID) {
			_custodianSent(_addr[1], _addr[0], _value);
		} else if (!_isBalanceSet(_addr[0])) {
			balances[_addr[0]] = token.balanceOf(_addr[0]).add(_value);
		}
		if (_rating[1] == 0 && _id[1] != ownerID) {
			_custodianReceived(_addr[0], _addr[1], _value);
		} else if (!_isBalanceSet(_addr[1])) {
			_setBalance(_addr[1], token.balanceOf(_addr[1]).sub(_value));
		}
		return true;
	}

	/**
		@notice Hook method, record checkpoint value after a custodial transfer
		@param _cust Custodian address
		@param _addr Sender/Receiver address
		@param _value Amount transferred
		@return bool
	 */
	function transferTokensCustodian(
		address _cust,
		address[2] _addr,
		bytes32[2],
		uint8[2],
		uint16[2],
		uint256 _value
	)
		external
		returns (bool)
	{
		require(msg.sender == address(token));
		if (now >= checkpointTime) {
			_custodianSent(_addr[0], _cust, _value);
			_custodianReceived(_addr[1], _cust, _value);
		}
		return true;
	}

	/**
		@notice Hook method, record checkpoint value after mint/burn
		@param _addr Investor address
		@param _old Old balance
		@param _new New balance
		@return bool
	 */
	function totalSupplyChanged(
		address _addr,
		bytes32,
		uint8,
		uint16,
		uint256 _old,
		uint256 _new
	)
		external
		returns (bool)
	{
		require(msg.sender == address(token));
		if (now < checkpointTime) {
			totalSupply = totalSupply.add(_new).sub(_old);
			return true;
		}
		if (_isBalanceSet(_addr)) return true;
		_setBalance(_addr, _old);
		return true;
	}

}
