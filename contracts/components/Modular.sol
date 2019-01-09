pragma solidity ^0.4.24;

import "../interfaces/IModules.sol";


/** @title Modular Functionality */
contract Modular {

	struct Module {
		bool active;
		// call out, call in
        mapping(bytes4 => bool[2]) permissions;
	}

	address[] modules;
    //Module[] modules;
	mapping (address => Module) modulePermissions;

	event ModuleAttached(address module, bytes4[] hooks);
	event ModuleDetached(address module);

	/**
		@notice Internal function to attach a module
		@dev This is called by attachModule() in the inheriting contract
		@param _module Address of the module to attach
	 */
	function _attachModule(address _module) internal {
		require (!modulePermissions[_module].active);
		IBaseModule b = IBaseModule(_module);
		require (b.getOwner() == address(this));
		bytes4[] memory _hooks = b.getHooks();
		modulePermissions[_module].active = true;
		modules.push(_module);
		//_setHooks(_module, _hooks, true);
		emit ModuleAttached(_module, _hooks);
	}

	/**
		@notice Internal function to detach a module
		@dev This is called by detachModule() in the inheriting contract
		@param _module Address of the module to detach
	 */
	function _detachModule(address _module) internal {
		require (modules.length > 0);
        if (modules[modules.length-1] == _module) {
            modules.length--;
            return;
        }
        for (uint256 i = 0; i < modules.length-1; i++) {
			if (modules[i] == _module) {
				//_setHooks(i, IBaseModule(modules[i].module).getHooks(), false);
				modules[i] = modules[modules.length-1];
                modules.length--;
				modulePermissions[_module].active = false;
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
	function _setHooks(address _module, bytes4[] _hooks, bool _set) private {
		for (uint256 i = 0; i < _hooks.length; i++) {
			modulePermissions[_module].permissions[_hooks[i]][0] = _set;
		}
	}

	/**
		@notice Internal function to iterate and call modules
		@param _sig bytes4 signature to call module with
		@param _data calldata to send to module
	 */
	function _callModules(bytes4 _sig, bytes _data) internal {
		for (uint256 i = 0; i < modules.length; i++) {
			if (modulePermissions[modules[i]].permissions[_sig][0]) {
				require(modules[i].call(_sig, _data));
			}
		}
	}

	/**
		@notice Determines if a module is active on this contract
		@param _module Deployed module address
		@return bool
	 */
	function isActiveModule(address _module) public view returns (bool) {
		return modulePermissions[_module].active;
	}

}
