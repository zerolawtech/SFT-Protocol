pragma solidity >=0.4.24 <0.5.0;


import "../../bases/MultiSig.sol";
import "../../IssuingEntity.sol";
import "../../SecurityToken.sol";

/**
	@title ModuleBase Abstract Base Contract
	@dev Methods in this ABC are defined in contracts that inherit ModuleBase
*/
contract ModuleBaseABC {
	function getPermissions() external pure returns (bytes4[], bytes4[], uint256);
}


/**
	@title Module Base Contract
	@dev Inherited contract for Custodian modules
*/
contract ModuleBase is ModuleBaseABC {

	bytes32 public ownerID;
	address owner;

	/**
		@notice Base constructor
		@param _owner Contract address that module will be attached to
	 */
	constructor(address _owner) public {
		owner = _owner;
		ownerID = MultiSig(_owner).ownerID();
	}

	/** @dev Check that call originates from approved authority, allows multisig */
	function _onlyAuthority() internal returns (bool) {
		return MultiSig(owner).checkMultiSigExternal(
			msg.sender,
			keccak256(msg.data),
			msg.sig
		);
	}

	/**
		@notice Fetch address of issuer contract that module is active on
		@return Owner contract address
	*/
	function getOwner() public view returns (address) {
		return owner;
	}

}


/**
	@title Token Module Base Contract
	@dev Inherited contract for SecurityToken or NFToken modules
 */
contract STModuleBase is ModuleBase {

	SecurityToken public token;
	IssuingEntity public issuer;

	/**
		@notice Base constructor
		@param _token SecurityToken contract address
		@param _issuer IssuingEntity contract address
	 */
	constructor(
		SecurityToken _token,
		address _issuer
	)
		public
		ModuleBase(_issuer)
	{
		token = _token;
		issuer = IssuingEntity(_issuer);
	}

	/** @dev Check that call originates from parent token contract */
	function _onlyToken() internal view {
		require(msg.sender == address(token));
	}

	/**
		@notice Fetch address of token that module is active on
		@return Token address
	*/
	function getOwner() public view returns (address) {
		return address(token);
	}

}


contract IssuerModuleBase is ModuleBase {

	IssuingEntity public issuer;
	mapping (address => bool) parents;

	/**
		@notice Base constructor
		@param _issuer IssuingEntity contract address
	 */
	constructor(address _issuer) public ModuleBase(_issuer) {
		issuer = IssuingEntity(_issuer);
	}

	/** @dev Check that call originates from token contract */
	function _onlyToken() internal {
		if (!parents[msg.sender]) {
			parents[msg.sender] = issuer.isActiveToken(msg.sender);
		}
		require (parents[msg.sender]);
	}

}
