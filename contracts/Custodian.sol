pragma solidity ^0.4.24;

import "./KYCRegistrar.sol";
import "./interfaces/STModule.sol";
import "./SecurityToken.sol";

/// @title Custodian Contract
contract Custodian {

	string public name;
	bytes32 public id;
	mapping (address => bool) public addresses;

	constructor (string _name) public {
		name = _name;
		id = keccak256(abi.encodePacked(address(this)));
	}

	function transfer (address _token, address _to, uint256 _value) external returns (bool) {
		require(addresses[msg.sender]);
		require(SecurityToken(_token).transfer(_to, _value));
		return true;
	}

	function addAddresses(address[] _addr) external returns (bool) {
		for (uint i = 0; i < _addr.length; i++) {
			addresses[_addr[i]] = true;
		}
		return true;
	}
	
	function removeAddresses(address[] _addr) external returns (bool) {
		for (uint i = 0; i < _addr.length; i++) {
			addresses[_addr[i]] = false;
		}
		return true;
	}

}
