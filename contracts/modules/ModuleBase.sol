pragma solidity ^0.4.24;

import "../SecurityToken.sol";
import "../IssuingEntity.sol";

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

	constructor(address _token, address _issuer) public {
		issuer = IssuingEntity(_issuer);
		token = SecurityToken(_token);
		ownerID = issuer.ownerID();
	}

	function () public payable {
		revert();
	}

	function owner() public view returns (address) {
		return address(token);
	}

}

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

	constructor(address _issuer) public {
		issuer = IssuingEntity(_issuer);
		ownerID = issuer.ownerID();
	}

	function () public payable {
		revert();
	}

	function owner() public view returns (address) {
		return address(issuer);
	}

}
