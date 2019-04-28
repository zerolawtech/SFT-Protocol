pragma solidity >=0.4.24 <0.5.0;

import "./bases/Token.sol";

/**
	@title Non-Fungible SecurityToken 
	@dev
		Expands upon the ERC20 token standard
		https://theethereum.wiki/w/index.php/ERC20_Token_Standard
	@dev	
		This contract has not been open sourced, the public version
		is only an ABC to simplify interaction and integration with other
		projects.
 */
contract NFToken is TokenBase  {

	event TransferRange(
		address indexed from,
		address indexed to,
		uint256 start,
		uint256 stop,
		uint256 amount
	);
	event RangeSet(
		bytes2 indexed tag,
		uint256 start,
		uint256 stop,
		uint32 time
	);

	/**
		@notice Security token constructor
		@dev Initially the total supply is credited to the issuer
		@param _issuer Address of the issuer's IssuingEntity contract
		@param _name Name of the token
		@param _symbol Unique ticker symbol
		@param _authorizedSupply Initial authorized token supply
	 */
	constructor(
		IssuingEntity _issuer,
		string _name,
		string _symbol,
		uint256 _authorizedSupply
	)
		public
		TokenBase(
			_issuer,
			_name,
			_symbol,
			_authorizedSupply
		)
	{
		return;
	}

	/**
		@notice ERC-20 balanceOf standard
		@param _owner Address of balance to query
		@return integer
	 */
	function balanceOf(address _owner) public view returns (uint256);

	/**
		@notice Fetch information about a range
		@param _idx Token index number
		@return owner, start of range, stop of range, time restriction, tag
	 */
	function getRange(
		uint256 _idx
	)
		external
		view
		returns (
			address _owner,
			uint48 _start,
			uint48 _stop,
			uint32 _time,
			bytes2 _tag,
			address _custodian
		);
	
	/**
		@notice Fetch the token ranges owned by an address
		@param _owner Address to query
		@return Array of [(start, stop),..]
	 */
	function rangesOf(address _owner) external view returns (uint48[2][]);

	/**
		@notice Fetch the token ranges owned by an address and held by a custodian
		@param _owner Address to query
		@param _custodian Address of custodian
		@return Array of [(start, stop),..]
	 */
	function custodianRangesOf(
		address _owner,
		address _custodian
	)
		external
		view
		returns
		(uint48[2][]);

	/**
		@notice Mints new tokens
		@param _owner Address to assign new tokens to
		@param _value Number of tokens to mint
		@param _time Time restriction to apply to tokens
		@param _tag Tag to apply to tokens
		@return Bool success
	 */
	function mint(
		address _owner,
		uint48 _value,
		uint32 _time,
		bytes2 _tag
	)
		external
		returns (bool);

	/**
		@notice Burns tokens
		@dev Cannot burn multiple ranges in a single call
		@param _start Start index of range to burn
		@param _stop Stop index of range to burn
		@return Bool success
	 */
	function burn(uint48 _start, uint48 _stop) external returns (bool);

	/**
		@notice Modifies a single range
		@dev If changes allow it, range will be merged with neighboring ranges
		@param _pointer Start index of range to modify
		@param _time New time restriction value
		@param _tag New tag value
		@return Bool success
	 */
	function modifyRange(
		uint48 _pointer,
		uint32 _time,
		bytes2 _tag
	)
		public
		returns (bool);

	/**
		@notice Modifies one or more ranges
		@dev Whenever possible, ranges will be merged
		@param _start Start index
		@param _stop Stop index
		@param _time New time restriction value
		@param _tag New tag value
		@return Bool success
	 */
	function modifyRanges(
		uint48 _start,
		uint48 _stop,
		uint32 _time,
		bytes2 _tag
	)
		public
		returns (bool);

	/**
		@notice ERC-20 transfer standard
		@dev calls to _checkTransfer() to verify permission before transferring
		@param _to Recipient
		@param _value Amount being transferred
		@return bool success
	 */
	function transfer(address _to, uint256 _value) external returns (bool);

	/**
		@notice ERC-20 transferFrom standard
		@dev This will transfer tokens starting from balance.ranges[0]
		@param _from Sender address
		@param _to Receipient address
		@param _value Number of tokens to send
		@return bool success
	 */
	function transferFrom(
		address _from,
		address _to,
		uint256 _value
	)
		external
		returns (bool);

	/**
		@notice Custodian transfer function
		@dev
			called by Custodian.transferInternal to change ownership within
			the custodian contract without moving any tokens
		@param _addr Sender/Receiver addresses
		@param _value Amount to transfer
		@return bool
	 */
	function transferCustodian(
		address[2] _addr,
		uint256 _value
	)
		public
		returns (bool);

	/**
		@notice transfer tokens with a specific index range
		@dev Can send tokens into a custodian, but not out of one
		@param _to Receipient address
		@param _start Transfer start index
		@param _stop Transfer stop index
		@return bool success
	 */
	function transferRange(
		address _to,
		uint48 _start,
		uint48 _stop
	)
		external
		returns (bool);
}