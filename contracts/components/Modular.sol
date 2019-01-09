pragma solidity ^0.4.24;

import "../interfaces/IModules.sol";


/** @title Modular Functionality */
contract Modular {

	struct Module {
		bool active;
		bool set;
		/* Outbound calls, inbound calls */
		mapping(bytes4 => bool[2]) permissions;
	}

	address[] modules;
	mapping (address => Module) modulePermissions;

	event ModuleAttached(address module, bytes4[] outbound, bytes4[] inbound);
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
		modulePermissions[_module].active = true;
		modules.push(_module);
		/* permissions can only be set the first time a module is attached */
		if (!modulePermissions[_module].set) {
			(
				bytes4[] memory _outbound,
				bytes4[] memory _inbound
			) = b.getPermissions();
			_setPermissions(_module, _outbound, 0);
			_setPermissions(_module, _inbound, 1);
			modulePermissions[_module].set = true;
		}
		emit ModuleAttached(_module, _outbound, _inbound);
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
		@param _module module address
		@param _sig array of function signatures
		@param _idx permission arary index
	 */
	function _setPermissions(
		address _module,
		bytes4[] _sig,
		uint256 _idx
	)
		private
	{
		for (uint256 i = 0; i < _sig.length; i++) {
			modulePermissions[_module].permissions[_sig[i]][_idx] = true;
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
		@notice Check if a module is active on this contract
		@param _module Deployed module address
		@return bool active
	 */
	function isActiveModule(address _module) public view returns (bool) {
		return modulePermissions[_module].active;
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
			modulePermissions[_module].active && 
			modulePermissions[_module].permissions[_sig][1]
		);
	}

}
