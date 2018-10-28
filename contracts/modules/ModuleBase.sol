pragma solidity ^0.4.24;

import "../SecurityToken.sol";
import "../IssuingEntity.sol";

contract ModuleBase {

	bytes32 public issuerID;
	IssuingEntity public issuer;

	modifier onlyIssuer () {
		require (issuer.owners(msg.sender));
		_;
	}

	constructor(address _issuer) public {
		issuer = IssuingEntity(_issuer);
		issuerID = issuer.issuerID();
	}

}

contract STModuleBase is ModuleBase {

	SecurityToken public token;

	modifier onlyParent() {
		require (msg.sender == address(token) || msg.sender == address(token.issuer()));
		_;
	}

	constructor(address _token, address _issuer) ModuleBase(_issuer) public {
		token = SecurityToken(_token);
	}

	function owner() public view returns (address) {
		return address(token);
	}

}

contract IssuerModuleBase is ModuleBase {

	IssuingEntity public issuer;

	modifier onlyParent() {
		require (msg.sender == address(issuer));
		_;
	}

	constructor(address _issuer) ModuleBase(_issuer) public {
		
	}

	function owner() public view returns (address) {
		return address(issuer);
	}

}
