pragma solidity ^0.4.24;

import "../SecurityToken.sol";
import "../IssuingEntity.sol";

///@title SecurityToken Module Base Contract
contract STModuleBase {

	bytes32 public ownerID;
	IssuingEntity public issuer;
	SecurityToken public token;

	modifier onlyParent() {
		require (msg.sender == address(token) || msg.sender == address(issuer));
		_;
	}

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

	function owner() public view returns (address) {
		return address(token);
	}

}

///@title IssuingEntity Module Base Contract
contract IssuerModuleBase {

	bytes32 public ownerID;
	IssuingEntity public issuer;

	modifier onlyParent() {
		require (msg.sender == address(issuer));
		_;
	}

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

	function owner() public view returns (address) {
		return address(issuer);
	}

}
