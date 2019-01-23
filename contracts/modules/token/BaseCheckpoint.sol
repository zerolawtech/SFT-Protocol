pragma solidity >=0.4.24 <0.5.0;

import "../../open-zeppelin/SafeMath.sol";
import "../ModuleBase.sol";
import "../../Custodian.sol";

contract CheckpointModule is STModuleBase {

	using SafeMath for uint256;

	uint256 time;
	uint256 totalSupply;
	mapping (address => uint256) balance;
	mapping (address => bool) zeroBalance;

	mapping (address => mapping(bytes32 => uint256)) custodianBalance;
	mapping (address => mapping(bytes32 => bool)) custodianZeroBalance;

	constructor(
		address _token,
		address _issuer,
		uint256 _time
	)
		STModuleBase(_token, _issuer)
		public
	{
		require (_time >= now);
		totalSupply = token.totalSupply();
		time = _time;
		hooks.push(0x35a341da);
		hooks.push(0x4268353d);
		hooks.push(0x4f072579);
	}

	function _getBalance(address _owner) internal view returns (uint256) {
		if (balance[_owner] > 0) return balance[_owner];
		if (zeroBalance[_owner]) return 0;
		return token.balanceOf(_owner);
	}

	function _getCustodianBalance(address _custodian, bytes32 _id) internal view returns (uint256) {
		if (custodianBalance[_custodian][_id] > 0) return custodianBalance[_custodian][_id];
		if (custodianZeroBalance[_custodian][_id]) return 0;
		return Custodian(_custodian).balanceOf(token, _id);
	}

	function transferTokens(
		address[2] _addr,
		bytes32[2] _id,
		uint8[2] _rating,
		uint16[2],
		uint256 _value
	)
		external
		onlyOwner
		returns (bool)
	{
		if (now < time) return true;
		if (_rating[0] == 0 && _id[0] != ownerID) {
			_checkCustodianSent(Custodian(_addr[0]), _id[1], _value);
		} else if (balance[_addr[0]] == 0 && !zeroBalance[_addr[0]]) {
			balance[_addr[0]] = token.balanceOf(_addr[0]).add(_value);
		}
		if (_rating[1] == 0 && _id[1] != ownerID) {
			_checkCustodianReceived(Custodian(_addr[1]), _id[0], _value);
		} else if (balance[_addr[1]] == 0 && !zeroBalance[_addr[1]]) {
			uint256 _bal = token.balanceOf(_addr[1]).sub(_value);
			if (_bal == 0) {
				zeroBalance[_addr[1]] == true;
			} else {
				balance[_addr[1]] = _bal;
			}
		}
		return true;
	}

	function _checkCustodianSent(Custodian _cust, bytes32 _id, uint256 _value) internal {
		if (
			custodianBalance[_cust][_id] == 0 &&
			!custodianZeroBalance[_cust][_id]
		) {
			custodianBalance[_cust][_id] = _cust.balanceOf(token, _id).add(_value);
		}
	}

	function _checkCustodianReceived(Custodian _cust, bytes32 _id, uint256 _value) internal {
		if (
			custodianBalance[_cust][_id] == 0 &&
			!custodianZeroBalance[_cust][_id]
		) {
			uint256 _bal = _cust.balanceOf(token, _id).sub(_value);
			if (_bal == 0) {
				custodianZeroBalance[_cust][_id] == true;
			} else {
				custodianBalance[_cust][_id] = _bal;
			}
		}
	}

	function transferTokensCustodian(
		Custodian _cust,
		bytes32[2] _id,
		uint8[2],
		uint16[2],
		uint256 _value
	)
		external
		returns (bool)
	{
		if (now < time) return true;
		_checkCustodianSent(_cust, _id[0], _value);
		_checkCustodianReceived(_cust, _id[1], _value);
		return true;
	}

	function balanceChanged(
		address _addr,
		bytes32,
		uint8,
		uint16,
		uint256 _old,
		uint256 _new
	)
		external
		onlyOwner
		returns (bool)
	{
		if (now < time) {
			totalSupply = totalSupply.add(_new).sub(_old);
			return true;
		}
		if (balance[_addr] > 0) return true;
		if (zeroBalance[_addr]) return true;
		if (_old > 0) {
			balance[_addr] = _old;
		} else {
			zeroBalance[_addr] = true;
		}
		return true;
	}

}
