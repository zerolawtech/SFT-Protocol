pragma solidity >=0.4.24 <0.5.0;

/**
	@notice Common interface for all modules
	@dev
		These are the minimum required methods that MUST be included to
		attach the module to the parent contract
*/
interface IBaseModule {

	/**
		@notice Defines the permissions for a module when it is attached
		@dev https://sft-protocol.readthedocs.io/en/latest/modules.html#ModuleBase.getPermissions
		@return permissions array, hooks array, hook attachments bitfield
	 */
	function getPermissions()
		external
		pure
		returns (
			bytes4[] permissions,
			bytes4[] hooks,
			uint256 hookBools
		);
	function getOwner() external view returns (address);
}

/**
	@notice SecurityToken module interface
	@dev These are all the possible hook point methods for token modules
*/
contract ISTModule is IBaseModule {
	
	function token() external returns (address);
	
	/**
		@notice Check if a transfer is possible
		@dev
			Called before a token transfer to check if it is permitted
			Hook signature: 0x70aaf928
		@param _addr sender and receiver addresses
		@param _authID id hash of caller
		@param _id sender and receiver id hashes
		@param _rating sender and receiver investor ratings
		@param _country sender and receiver country codes
		@param _value amount of tokens to be transfered
		@return bool success
	 */
	function checkTransfer(
		address[2] _addr,
		bytes32 _authID,
		bytes32[2] _id,
		uint8[2] _rating,
		uint16[2] _country,
		uint256 _value
	)
		external
		view
		returns (bool);

	/**
		@notice Token transfer
		@dev
			Called a token transfer has completed
			Hook signature: 0x35a341da
		@param _addr sender and receiver addresses
		@param _id sender and receiver id hashes
		@param _rating sender and receiver investor ratings
		@param _country sender and receiver country codes
		@param _value amount of tokens to be transfered
		@return bool success
	 */
	function transferTokens(
		address[2] _addr,
		bytes32[2] _id,
		uint8[2] _rating,
		uint16[2] _country,
		uint256 _value
	)
		external
		returns (bool);

	/**
		@notice Token custodial internal transfer
		@dev
			Called a custodian internal token transfer has completed
			Hook signature: 0x8b5f1240
		@param _custodian custodian address
		@param _addr sender and receiver addresses
		@param _id sender and receiver id hashes
		@param _rating sender and receiver investor ratings
		@param _country sender and receiver country codes
		@param _value amount of tokens to be transfered
		@return bool success
	 */
	function transferTokensCustodian(
		address _custodian,
		address[2] _addr,
		bytes32[2] _id,
		uint8[2] _rating,
		uint16[2] _country,
		uint256 _value
	)
		external
		returns (bool);


	/**
		@notice Modify authorized supply
		@dev
			Called before modifying the authorized supply of a token
			Hook signature: 0xa5f502c1
		@param _oldSupply Current authorized supply
		@param _newSupply New authorized suppply
		@return bool success
	 */
	function modifyAuthorizedSupply(
		uint256 _oldSupply,
		uint256 _newSupply
	)
		external
		returns (bool);

	/**
		@notice Total supply changed
		@dev
			Called after the total supply has been changed via minting or burning
			Hook signature: 0x741b5078
		@param _addr Address where balance has changed
		@param _id ID that the address is associated to
		@param _rating Investor rating
		@param _country Investor country code
		@param _old Previous token balance at the address
		@param _new New token balance at the address
		@return bool success
	 */
	function totalSupplyChanged(
		address _addr,
		bytes32 _id,
		uint8 _rating,
		uint16 _country,
		uint256 _old,
		uint256 _new
	)
		external
		returns (bool);
}

/**
	@notice NFToken module interface
	@dev
		These are all the possible hook point methods for NFToken modules
		All SecurityToken module hook points are also available
*/
contract INFTModule is ISTModule {

	/**
		@notice Check if a transfer is possible
		@dev
			Called before a token transfer to check if it is permitted
			Hook signature: 0x70aaf928
		@param _addr sender and receiver addresses
		@param _authID id hash of caller
		@param _id sender and receiver id hashes
		@param _rating sender and receiver investor ratings
		@param _country sender and receiver country codes
		@param _range start and stop index of transferred range
		@return bool success
	 */
	function checkTransferRange(
		address[2] _addr,
		bytes32 _authID,
		bytes32[2] _id,
		uint8[2] _rating,
		uint16[2] _country,
		uint48[2] _range
	)
		external
		view
		returns (bool);

	/**
		@notice Token range transfer
		@dev
			Called a range of tokens has been transferred
			Hook signature: 0xead529f5 (taggable)
		@param _addr sender and receiver addresses
		@param _id sender and receiver id hashes
		@param _rating sender and receiver investor ratings
		@param _country sender and receiver country codes
		@param _range start and stop index of transferred range
		@return bool success
	 */
	function transferTokenRange(
		address[2] _addr,
		bytes32[2] _id,
		uint8[2] _rating,
		uint16[2] _country,
		uint48[2] _range
	)
		external
		returns (bool);

}

/**
	@notice Custodian module interface
	@dev These are all the possible hook point methods for custodian modules
*/
contract ICustodianModule is IBaseModule {

	/**
		@notice Custodian sent tokens
		@dev
			Called after a successful token transfer from the custodian.
			Hook signature: 0xb4684410
		@param _token Token address
		@param _to Recipient address
		@param _value Amount of tokens transfered
		@return bool success
	 */
	function sentTokens(
		address _token,
		address _to,
		uint256 _value
	)
		external
		returns (bool);

	/**
		@notice Custodian received tokens
		@dev
			Called after a successful token transfer to the custodian.
			Hook signature: 0xb15bcbc4
		@param _token Token address
		@param _from Sender address
		@param _value Amount of tokens transfered
		@return bool success
	 */
	function receivedTokens(
		address _token,
		address _from,
		uint256 _value
	)
		external
		returns (bool);

	/**
		@notice Custodian internal token transfer
		@dev
			Called after a successful internal token transfer by the custodian
			Hook signature: 0x44a29e2a
		@param _token Token address
		@param _from Sender address
		@param _value Amount of tokens transfered
		@return bool success
	 */
	function internalTransfer(
		address _token,
		address _from,
		address _to,
		uint256 _value
	)
		external
		returns (bool);
}