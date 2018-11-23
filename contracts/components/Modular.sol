pragma solidity ^0.4.24;

import "../interfaces/Modules.sol";


/** @title Modular Functionality for IssuingEntity and SecurityToken */
contract Modular {

	struct Module {
		address module;
		mapping(bytes4 => bool) hooks;
	}

	Module[] modules;
	mapping (address => bool) activeModules;

	event ModuleAttached(address module, bytes4[] hooks);
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
		bytes4[] memory _hooks = b.getHooks();
		activeModules[_module] = true;
		for (uint256 i = 0; i < modules.length; i++) {
			if (modules[i].module == 0) {
				modules[i].module = _module;
				_setHooks(i, _hooks, true);
				emit ModuleAttached(_module, _hooks);
				return;
			}
		}
		modules.push(Module(_module));
		_setHooks(modules.length-1, _hooks, true);
		emit ModuleAttached(_module, _hooks);
	}

	/**
		@notice Internal function to detach a module
		@dev This is called by detachModule() in the inheriting contract
		@param _module Address of the module to detach
	 */
	function _detachModule(address _module) internal {
		for (uint256 i = 0; i < modules.length; i++) {
			if (modules[i].module == _module) {
				_setHooks(i, IBaseModule(modules[i].module).getHooks(), false);
				modules[i].module = 0;
				activeModules[_module] = false;
				emit ModuleDetached(_module);
				return;
			}
		}
		revert();
	}

	/**
		@notice Internal to modify module hooks mapping
		@param _idx modules array index
		@param _hooks bytes4 array
		@param _set value to apply to mapping
	 */
	function _setHooks(uint256 _idx, bytes4[] _hooks, bool _set) private {
		for (uint256 i = 0; i < _hooks.length; i++) {
			modules[_idx].hooks[_hooks[i]] = _set;
		}
	}

	/**
		@notice Internal function to iterate and call modules
		@param _sig bytes4 signature to call module with
		@param _data calldata to send to module
	 */
	function _callModules(bytes4 _sig, bytes _data) internal {
		for (uint256 i = 0; i < modules.length; i++) {
			if (address(modules[i].module) != 0 && modules[i].hooks[_sig]) {
				require(modules[i].module.call(_sig, _data));
			}
		}
	}

	/**
		@notice Determines if a module is active on this issuing entity
		@param _module Deployed module address
		@return bool
	 */
	function isActiveModule(address _module) public view returns (bool) {
		return activeModules[_module];
	}

}
