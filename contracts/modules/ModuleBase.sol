pragma solidity ^0.4.24;

import "../SecurityToken.sol";
import "../KYCRegistrar.sol";
import "../IssuingEntity.sol";

contract _ModuleBase {

	bytes32 public issuerID;
	KYCRegistrar public registrar;
	IssuingEntity public issuer;

	constructor(address _issuer) public {
		issuer = IssuingEntity(_issuer);
		issuerID = issuer.issuerID();
		registrar = KYCRegistrar(issuer.registrar());
	}

	modifier onlyIssuer () {
		require (issuer.issuerAddr(msg.sender));
		_;
	}

}

contract STModuleBase is _ModuleBase {

	SecurityToken public token;

	constructor(address _token, address _issuer) _ModuleBase(_issuer) public {
		token = SecurityToken(_token);
		registrar = KYCRegistrar(token.registrar());
	}

	modifier onlyParent() {
		require (msg.sender == address(token) || msg.sender == address(token.issuer()));
		_;
	}

	function owner() public view returns (address) {
		return address(token);
	}

}

contract IssuerModuleBase is _ModuleBase {

	IssuingEntity public issuer;

	modifier onlyParent() {
		require (msg.sender == address(issuer));
		_;
	}

	function owner() public view returns (address) {
		return address(issuer);
	}

}
