pragma solidity ^0.4.24;

import "../interfaces/STModule.sol";


/** @title Modular Functionality for IssuingEntity and SecurityToken */
contract Modular {

	struct Module {
		address module;
		bool[3] hooks;
	}

	Module[] modules;
	mapping (address => bool) activeModules;

	event ModuleAttached(address module, bool check, bool transfer, bool balance);
	event ModuleDetached(address module);

	/**
		@notice Internal function to attach a module
		@dev This is called by attachModule() in the inheriting contract
		@param _module Address of the module to attach
	 */
	function _attachModule(address _module) internal {
		require (!activeModules[_module]);
		IBaseModule b = IBaseModule(_module);
		require (b.owner() == address(this));
		bool[3] memory _hooks = b.getBindings();
		activeModules[_module] = true;
		for (uint256 i = 0; i < modules.length; i++) {
			if (modules[i].module == 0) {
				modules[i] = Module(_module, _hooks);
				emit ModuleAttached(_module, _hooks[0], _hooks[1], _hooks[2]);
				return;
			}
		}
		modules.push(Module(_module, _hooks));
		emit ModuleAttached(_module, _hooks[0], _hooks[1], _hooks[2]);
	}

	/**
		@notice Internal function to detach a module
		@dev This is called by detachModule() in the inheriting contract
		@param _module Address of the module to detach
	 */
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
		@notice Internal function to iterate and call modules
		@param _hook Index of module hooks bool[] to know if it should be called
		@param _sig bytes4 signature to call module with
		@param _data calldata to send to module
	 */
	function _callModules(uint256 _hook, bytes4 _sig, bytes _data) internal {
		for (uint256 i = 0; i < modules.length; i++) {
			if (address(modules[i].module) != 0 && modules[i].hooks[_hook]) {
				require(modules[i].module.call(_sig, _data));
			}
		}
	}

}
