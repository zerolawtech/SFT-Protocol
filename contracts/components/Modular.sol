pragma solidity ^0.4.24;

import "../interfaces/STModule.sol";


/// @title Security Token Base
contract Modular {

	struct Module {
		address module;
		bool[3] hooks;
	}

	/* Modules are loaded on an as-needed basis to keep gas costs minimal. */
	Module[] modules;
	mapping (address => bool) activeModules;

	//event ModuleAttached(address module, bool check, bool transfer, bool balance);
	event ModuleDetached(address module);

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
		bool[3] memory _hooks = b.getBindings();
		activeModules[_module] = true;
		for (uint256 i = 0; i < modules.length; i++) {
			if (modules[i].module == 0) {
				modules[i] = Module(_module, _hooks);
				//emit ModuleAttached(_module, _check, _transfer, _balance);
				return;
			}
		}
		modules.push(Module(_module, _hooks));
		//emit ModuleAttached(_module, _check, _transfer, _balance);
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

	/**
		@notice Iterate through active modules and call any 
	 */
	function _callModules(uint256 _hook, bytes4 _sig, bytes _data) internal {
		for (uint256 i = 0; i < modules.length; i++) {
			if (address(modules[i].module) != 0 && modules[i].hooks[_hook]) {
				require(modules[i].module.call(_sig, _data));
			}
		}
	}

}
