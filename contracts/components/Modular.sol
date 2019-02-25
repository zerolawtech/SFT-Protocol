pragma solidity ^0.4.24;

import "../interfaces/IModules.sol";


/** @title Modular Functionality */
contract Modular {

	struct Module {
		bool active;
		bool set;
		/* hooks, permissions */
		mapping(bytes4 => bool) hooks;
		mapping(bytes4 => bool) permissions;
	}

	address[] activeModules;
	mapping (address => Module) moduleData;

	event ModuleAttached(address module, bytes4[] hooks, bytes4[] permissions);
	event ModuleDetached(address module);

	/**
		@notice Internal function to attach a module
		@dev This is called by attachModule() in the inheriting contract
		@param _module Address of the module to attach
	 */
	function _attachModule(address _module) internal {
		require (!moduleData[_module].active);
		IBaseModule b = IBaseModule(_module);
		require (b.getOwner() == address(this));
		moduleData[_module].active = true;
		activeModules.push(_module);
		/* signatures can only be set the first time a module is attached */
		if (!moduleData[_module].set) {
			(
				bytes4[] memory _hooks,
				bytes4[] memory _permissions
			) = b.getPermissions();
			for (uint256 i; i < _hooks.length; i++) {
				moduleData[_module].hooks[_hooks[i]] = true;
			}
			for (i = 0; i < _hooks.length; i++) {
				moduleData[_module].permissions[_permissions[i]] = true;
			}
			moduleData[_module].set = true;
		}
		emit ModuleAttached(_module, _hooks, _permissions);
	}

	/**
		@notice Internal function to detach a module
		@dev This is called by detachModule() in the inheriting contract
		@param _module Address of the module to detach
	 */
	function _detachModule(address _module) internal {
		require (
			moduleData[_module].active &&
			activeModules.length > 0
		);
		moduleData[_module].active = false;
		emit ModuleDetached(_module);
		if (activeModules[activeModules.length - 1] == _module) {
			activeModules.length--;
			return;
		}
		for (uint256 i = 0; i < activeModules.length - 1; i++) {
			if (activeModules[i] == _module) {
				activeModules[i] = activeModules[activeModules.length - 1];
				activeModules.length--;
				return;
			}
		}
		revert();
	}

	/**
		@notice Internal function to iterate and call modules
		@param _sig bytes4 signature to call module with
		@param _data calldata to send to module
	 */
	function _callModules(bytes4 _sig, bytes _data) internal {
		for (uint256 i = 0; i < activeModules.length; i++) {
			if (moduleData[activeModules[i]].hooks[_sig]) {
				require(activeModules[i].call(_sig, _data));
			}
		}
	}

	/**
		@notice Check if a module is active on this contract
		@param _module Deployed module address
		@return bool active
	 */
	function isActiveModule(address _module) public view returns (bool) {
		return moduleData[_module].active;
	}

	/**
		@notice Check if a module is permitted to access a specific function
		@dev
			This returns false instead of throwing because an issuer level 
			module must be checked twice
		@param _module Module address
		@param _sig Function signature
		@return bool permission
	 */
	function isPermittedModule(
		address _module,
		bytes4 _sig
	)
		public
		view
		returns (bool)
	{
		return (
			moduleData[_module].active && 
			moduleData[_module].permissions[_sig]
		);
	}

}
