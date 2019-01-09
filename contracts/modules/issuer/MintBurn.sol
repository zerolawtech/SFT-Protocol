pragma solidity ^0.4.24;

import "../../open-zeppelin/SafeMath.sol";
import "../ModuleBase.sol";
import "../../SecurityToken.sol";


contract MintBurnModule is ModuleBase {

	using SafeMath for uint256;

	string public name = "MintBurn";

	event TokensMinted(address indexed token, uint256 amount);
	event TokensBurned(address indexed token, uint256 amount);

	constructor(address _issuer) ModuleBase(_issuer) public { }

	function getPermissions() external pure returns (
		bytes4[] outbound,
		bytes4[] inbound
	) {
		bytes4[] memory _out = new bytes4[](0);
		bytes4[] memory _in = new bytes4[](1);
		_in[0] = 0x930e5004;
		return (_out, _in);
	}

	function mint(address _token, uint256 _value) external onlyAuthority returns (bool) {
		SecurityToken t = SecurityToken(_token);
		uint256 _new = t.balanceOf(owner).add(_value);
		require(t.modifyBalance(owner, _new));
		emit TokensMinted(_token, _value);
		return true;
	}

	function burn(address _token, uint256 _value) external onlyAuthority returns (bool) {
		SecurityToken t = SecurityToken(_token);
		uint256 _new = t.balanceOf(owner).sub(_value);
		require(t.modifyBalance(owner, _new));
		emit TokensBurned(_token, _value);
		return true;
	}
}
