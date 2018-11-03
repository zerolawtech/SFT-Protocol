pragma solidity ^0.4.24;

import "../SecurityToken.sol";
import "../IssuingEntity.sol";

contract STModuleBase {

	bytes32 public issuerID;
	IssuingEntity public issuer;
	SecurityToken public token;

	modifier onlyParent() {
		require (msg.sender == address(token) || msg.sender == address(token.issuer()));
		_;
	}

	modifier onlyIssuer () {
		require (issuer.owners(msg.sender));
		_;
	}

	constructor(address _token, address _issuer) public {
		issuer = IssuingEntity(_issuer);
		token = SecurityToken(_token);
	}

	function owner() public view returns (address) {
		return address(token);
	}

}

contract IssuerModuleBase {

	bytes32 public issuerID;
	IssuingEntity public issuer;

	modifier onlyParent() {
		require (msg.sender == address(issuer));
		_;
	}

	modifier onlyIssuer () {
		require (issuer.owners(msg.sender));
		_;
	}

	constructor(address _issuer) public {
		issuer = IssuingEntity(_issuer);
		issuerID = issuer.issuerID();
	}

	function owner() public view returns (address) {
		return address(issuer);
	}

}
