pragma solidity ^0.4.24;

import "../ModuleBase.sol";


contract CountryLockModule is STModuleBase {

	string public name = "CountryTimeLock";
	mapping (uint16 => uint256) public countryLock;

	constructor(
		address _token,
		address _issuer
	)
		STModuleBase(_token, _issuer)
		public
	{
		hooks.push(0x70aaf928);
	}

	function modifyCountryLock(uint16 _country, uint256 _epochTime) public onlyAuthority {
		countryLock[_country] = _epochTime;
	}

	function checkTransfer(
		address[2],
		bytes32,
		bytes32[2],
		uint8[2],
		uint16[2] _country,
		uint256
	)
		external
		view
		returns (bool)
	{
		require (countryLock[_country[0]] < now);
		require (countryLock[_country[1]] < now);
	}

}
