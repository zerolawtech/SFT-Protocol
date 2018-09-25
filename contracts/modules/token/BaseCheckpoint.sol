pragma solidity ^0.4.24;

import "../../open-zeppelin/SafeMath.sol";
import "../STBase.sol";


contract CheckpointModule is STModuleBase {

	using SafeMath for uint256;

	uint256 time;
	uint256 totalSupply;
	mapping (address => uint256) balance;
	mapping (address => bool) zeroBalance;

	constructor(address _token, uint256 _time) STModuleBase(_token) public {
		require (_time >= now);
		totalSupply = token.totalSupply();
		time = _time;
	}

	function _getBalance(address _owner) internal view returns (uint256) {
		if (balance[_owner] > 0) return balance[_owner];
		if (zeroBalance[_owner]) return 0;
		return token.balanceOf(_owner);
	}

	function transferTokens(
		address _from,
		address _to,
		uint256 _value
	)
		external
		onlyParent
		returns (bool)
	{
		if (now < time) return true;
		if (balance[_from] == 0 && !zeroBalance[_from]) {
			balance[_from] = token.balanceOf(_from).add(_value);
		}
		if (balance[_to] == 0 && !zeroBalance[_to]) {
			uint256 _bal = token.balanceOf(_to).sub(_value);
			if (_bal == 0) {
				zeroBalance[_to] == true;
			} else {
				balance[_to] = _bal;
			}
		}
		return true;
	}

	function balanceChanged(
		address _owner,
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
		if (balance[_owner] > 0) return true;
		if (zeroBalance[_owner]) return true;
		if (_old > 0) {
			balance[_owner] = _old;
		} else {
			zeroBalance[_owner] = true;
		}
		return true;
	}

	function getBindings() external pure returns (bool, bool, bool) {
		return (false, true, true);
	}

}
