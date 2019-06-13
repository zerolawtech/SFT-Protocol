pragma solidity >=0.4.24 <0.5.0;

import "../interfaces/IModules.sol";


/** @title Modular Functionality */
contract Modular {

	struct Module {
		bool active;
		bool set;
		/* hooks, permissions */
		mapping(bytes4 => Hook) hooks;
		mapping(bytes4 => bool) permissions;
	}

	struct Hook {
		uint256[256] tagBools;
		bool permitted;
		bool active;
		bool always;
	}

	address[] activeModules;
	mapping (address => Module) moduleData;

	event ModuleAttached(address module, bytes4[] hooks, bytes4[] permissions);
	event ModuleHookSet(address module, bytes4 hook, bool active, bool always);
	event ModuleDetached(address module);

	/**
		@notice get boolean from a bit field
		@param _bool uint256 boolean bitfield
		@param _i index of boolean
		@return bool
	 */
	function _getBool(uint256 _bool, uint256 _i) internal pure returns (bool) {
		return (_bool >> _i) & uint256(1) == 1;
	}

	/**
		@notice Attach a security token module
		@dev Can only be called indirectly from IssuingEntity.attachModule()
		@param _module Address of the module contract
		@return bool success
	 */
	function _attachModule(address _module) internal {
		require (!moduleData[_module].active); // dev: already active
		IBaseModule b = IBaseModule(_module);
		Module storage m = moduleData[_module];
		m.active = true;
		activeModules.push(_module);
		/* hooks and permissions are only set the first time a module attaches */
		if (!m.set) {
			(
				bytes4[] memory _permissions,
				bytes4[] memory _hooks,
				uint256 _hookBools
			) = b.getPermissions();
			for (uint256 i; i < _hooks.length; i++) {
				m.hooks[_hooks[i]].permitted = true;
				m.hooks[_hooks[i]].active = _getBool(_hookBools, i);
				m.hooks[_hooks[i]].always = _getBool(_hookBools, i+128);
				emit ModuleHookSet(
					_module,
					_hooks[i],
					m.hooks[_hooks[i]].active,
					m.hooks[_hooks[i]].always
				);
			}
			for (i = 0; i < _permissions.length; i++) {
				m.permissions[_permissions[i]] = true;
			}
			m.set = true;
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
		for (uint256 i; i < activeModules.length - 1; i++) {
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
		@param _tag bytes2 tag of related token range
		@param _data calldata to send to module
		@return bool did all called modules return true?
	 */
	function _callModules(
		bytes4 _sig,
		bytes2 _tag,
		bytes _data
	)
		internal
		returns (bool)
	{
		for (uint256 i; i < activeModules.length; i++) {
			Hook storage h = moduleData[activeModules[i]].hooks[_sig];
			if (!h.active) continue;
			if (h.always) {
				if (!activeModules[i].call(_sig, _data)) return false;
				continue;
			}
			if (_tag == 0x00) continue;
			uint256 _packedBool = h.tagBools[uint256(_tag[0])];
			if (_packedBool == 0) continue;
			if (
				/** hook for first byte of tag is true */
				_getBool(_packedBool, 0) ||
				/** hook for entire tag is true */
				_getBool(_packedBool, uint256(_tag[1]))
			) {
				if (!activeModules[i].call(_sig, _data)) return false;
				continue;
			}
		}
		return true;
	}

	/**
		@notice Enable or disable a hook point for an active module
		@dev Only callable from a module
		@param _sig bytes4 signature for hook point
		@param _active is this hook active?
		@param _always should this hook always be called, regardless of tag?
		@return bool success
	 */
	function setHook(
		bytes4 _sig,
		bool _active,
		bool _always
	)
		external
		returns (bool)
	{
		require (isActiveModule(msg.sender));
		Hook storage h = moduleData[msg.sender].hooks[_sig];
		require (h.permitted);
		h.active = _active;
		h.always = _always;
		return true;
	}

	/**
		@notice Enable or disable specific tags for a hook point
		@dev Only callable from a module
		@param _sig bytes4 signature for hook point
		@param _value boolean to set to tag hook points
		@param _tagBase first byte of tags to modify
		@param _tags array of 2nd byte of tags to modify
		@return bool success
	 */
	function setHookTags(
		bytes4 _sig,
		bool _value,
		bytes1 _tagBase,
		bytes1[] _tags
	)
		external
		returns (bool)
	{
		require (isActiveModule(msg.sender));
		Hook storage h = moduleData[msg.sender].hooks[_sig];
		require (h.permitted);
		uint256 _packedBool = h.tagBools[uint256(_tagBase)];
		for (uint256 i; i < _tags.length; i++) {
			if (_value) {
				_packedBool = _packedBool | uint256(1) << uint256(_tags[i]);
			} else {
				_packedBool = _packedBool & ~(uint256(1) << uint256(_tags[i]));
			}
		}
		h.tagBools[uint256(_tagBase)] = _packedBool;
		return true;
	}

	/**
		@notice Disable many tags for a given hook point
		@dev Only callable from a module
		@param _sig bytes4 signature for hook point
		@param _tagBase array of first byte of tags to disable
		@return bool success
	 */
	function clearHookTags(
		bytes4 _sig,
		bytes1[] _tagBase
	)
		external
		returns (bool)
	{
		require (isActiveModule(msg.sender));
		Hook storage h = moduleData[msg.sender].hooks[_sig];
		require (h.permitted);
		for (uint256 i; i < _tagBase.length; i++) {
			h.tagBools[uint256(_tagBase[i])] = 0;
		}
		return true;
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
