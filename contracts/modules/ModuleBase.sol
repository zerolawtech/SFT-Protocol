pragma solidity ^0.4.24;

import "../SecurityToken.sol";
import "../IssuingEntity.sol";

/** @title SecurityToken Module Base Contract */
contract STModuleBase {

	bytes32 public ownerID;
	IssuingEntity public issuer;
	SecurityToken public token;

	/** @dev Check that call originates from issuer or token contract */
	modifier onlyParent() {
		require (msg.sender == address(token) || msg.sender == address(issuer));
		_;
	}

	/** @dev Check that the call is from an approved authority */
	modifier onlyIssuer () {
		require (issuer.isApprovedAuthority(msg.sender, msg.sig));
		_;
	}

	/**
		@notice Base constructor
		@param _token SecurityToken contract address
		@param _issuer IssuingEntity contract address
	 */
	constructor(address _token, address _issuer) public {
		issuer = IssuingEntity(_issuer);
		token = SecurityToken(_token);
		ownerID = issuer.ownerID();
	}

	/**
		@notice Fetch address of token that module is active on
		@return Token address
	*/
	function owner() public view returns (address) {
		return address(token);
	}

}

/** @title IssuingEntity Module Base Contract */
contract IssuerModuleBase {

	bytes32 public ownerID;
	IssuingEntity public issuer;

	/** @dev Check that call originates from issuer or token contract */
	modifier onlyParent() {
		require (msg.sender == address(issuer));
		_;
	}

	/** @dev Check that the call is from an approved authority */
	modifier onlyIssuer () {
		require (issuer.isApprovedAuthority(msg.sender, msg.sig));
		_;
	}

	/**
		@notice Base constructor
		@param _issuer IssuingEntity contract address
	 */
	constructor(address _issuer) public {
		issuer = IssuingEntity(_issuer);
		ownerID = issuer.ownerID();
	}

	/**
		@notice Fetch address of issuer contract that module is active on
		@return Issuer contract address
	*/
	function owner() public view returns (address) {
		return address(issuer);
	}

}
