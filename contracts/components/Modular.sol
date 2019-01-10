pragma solidity ^0.4.24;

import "../interfaces/IModules.sol";


/** @title Modular Functionality */
contract Modular {

	struct Module {
		bool active;
		bool set;
		/* hooks, permissions */
		mapping(bytes4 => bool[2]) signatures;
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
			_setPermissions(_module, _hooks, 0);
			_setPermissions(_module, _permissions, 1);
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
			moduleData[_module].signatures[_sig[i]][_idx] = true;
		}
	}

	/**
		@notice Internal function to iterate and call modules
		@param _sig bytes4 signature to call module with
		@param _data calldata to send to module
	 */
	function _callModules(bytes4 _sig, bytes _data) internal {
		for (uint256 i = 0; i < activeModules.length; i++) {
			if (moduleData[activeModules[i]].signatures[_sig][0]) {
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
			moduleData[_module].signatures[_sig][1]
		);
	}

}
