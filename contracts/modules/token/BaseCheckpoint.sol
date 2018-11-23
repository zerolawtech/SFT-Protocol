pragma solidity ^0.4.24;

import "../../open-zeppelin/SafeMath.sol";
import "../ModuleBase.sol";


contract CheckpointModule is STModuleBase {

	using SafeMath for uint256;

	uint256 time;
	uint256 totalSupply;
	mapping (address => uint256) balance;
	mapping (address => bool) zeroBalance;

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
	}

	function _getBalance(address _owner) internal view returns (uint256) {
		if (balance[_owner] > 0) return balance[_owner];
		if (zeroBalance[_owner]) return 0;
		return token.balanceOf(_owner);
	}

	function transferTokens(
		address[2] _addr,
		bytes32[2],
		uint8[2],
		uint16[2],
		uint256 _value
	)
		external
		onlyParent
		returns (bool)
	{
		if (now < time) return true;
		if (balance[_addr[0]] == 0 && !zeroBalance[_addr[0]]) {
			balance[_addr[0]] = token.balanceOf(_addr[0]).add(_value);
		}
		if (balance[_addr[1]] == 0 && !zeroBalance[_addr[1]]) {
			uint256 _bal = token.balanceOf(_addr[1]).sub(_value);
			if (_bal == 0) {
				zeroBalance[_addr[1]] == true;
			} else {
				balance[_addr[1]] = _bal;
			}
		}
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
		onlyParent
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
