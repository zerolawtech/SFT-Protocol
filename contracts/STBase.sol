pragma solidity ^0.4.24;

import "./KYCRegistrar.sol";
import "./interfaces/STModule.sol";


/// @title Security Token Base
contract STBase {

	struct Module {
		address module;
		bool checkTransfer;
		bool transferTokens;
		bool balanceChanged;
	}

	/* Modules are loaded on an as-needed basis to keep gas costs minimal. */
	Module[] modules;
	mapping (address => bool) activeModules;

	event ModuleAttached(address module, bool check, bool transfer, bool balance);
	event ModuleDetached(address module);

	modifier onlyOwner() {
		_;
	}

	/// @notice Fallback function
	function () public payable {
		revert();
	}

	/// @notice Attach a module to a token
	/// @param _module Address of the deployed module
	/// @return boolean
	function _attachModule(address _module) internal {
		require (!activeModules[_module]);
		IBaseModule b = IBaseModule(_module);
		require (b.owner() == address(this));
		(bool _check, bool _transfer, bool _balance) = b.getBindings();
		activeModules[_module] = true;
		for (uint256 i = 0; i < modules.length; i++) {
			if (modules[i].module == 0) {
				modules[i].module = _module;
				modules[i].checkTransfer = _check;
				modules[i].transferTokens = _transfer;
				modules[i].balanceChanged = _balance;
				emit ModuleAttached(_module, _check, _transfer, _balance);
				return;
			}
		}
		modules.push(Module(_module, _check, _transfer, _balance));
		emit ModuleAttached(_module, _check, _transfer, _balance);
		return;
	}

	/// @notice Detach a module from a token
	/// @param _module of the deployed module
	/// @return boolean
	function _detachModule(address _module) internal {
		for (uint256 i = 0; i < modules.length; i++) {
			if (modules[i].module == _module) {
				modules[i].module = 0;
				activeModules[_module] = false;
				emit ModuleDetached(_module);
				return;
			}
		}
		revert();
	}
}
