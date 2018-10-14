pragma solidity ^0.4.24;

import "./KYCRegistrar.sol";
import "./interfaces/STModule.sol";


/// @title Security Token Base
contract STBase {

	bytes32 public issuerID;
	KYCRegistrar public registrar;
	bool public locked;

	struct Module {
		address module;
		bool checkTransfer;
		bool transferTokens;
		bool balanceChanged;
	}

	/* Modules are loaded on an as-needed basis to keep gas costs minimal. */
	Module[] modules;
	mapping (address => bool) activeModules;

	modifier onlyIssuer() {
		require (registrar.isPermittedIssuer(issuerID, msg.sender));
		_;
	}

	modifier onlyUnlocked() {
		require (!locked || registrar.getId(msg.sender) == issuerID);
		_;
	}

	/// @notice Fallback function
	function () public payable {
		revert();
	}

	/// @notice Lock all tokens
	/// @dev Issuer can transfer tokens regardless of lock status
	function lockTransfers() external onlyIssuer {
		locked = true;
	}

	/// @notice Unlock all tokens
	/// @dev Issuer can transfer tokens regardless of lock status
	function unlockTransfers() external onlyIssuer {
		locked = false;
	}

	/// @notice Attach a module to a token
	/// @param _module Address of the deployed module
	/// @return boolean
	function attachModule(address _module) external onlyIssuer returns (bool) {
		require (!activeModules[_module]);
		BaseModule b = BaseModule(_module);
		require (b.owner() == address(this));
		(bool _check, bool _transfer, bool _balance) = b.getBindings();
		activeModules[_module] = true;
		for (uint256 i = 0; i < modules.length; i++) {
			if (modules[i].module == 0) {
				modules[i].module = _module;
				modules[i].checkTransfer = _check;
				modules[i].transferTokens = _transfer;
				modules[i].balanceChanged = _balance;
				return true;
			}
		}
		modules.push(Module(_module, _check, _transfer, _balance));
		return true;
	}

	/// @notice Detach a module from a token
	/// @param _module of the deployed module
	/// @return boolean
	function detachModule(address _module) external returns (bool) {
		if (_module != msg.sender) {
			require (registrar.getId(msg.sender) == issuerID);
		}
		for (uint256 i = 0; i < modules.length; i++) {
			if (modules[i].module == _module) {
				modules[i].module = 0;
				activeModules[_module] = false;
				return true;
			}
		}
		revert();
	}
}
