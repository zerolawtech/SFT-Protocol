pragma solidity ^0.4.24;


interface IssuerFactoryInterface {
	function newIssuer(bytes32 _id) external returns (address);
}

interface TokenFactoryInterface {
	function newToken(address _issuer, string _name, string _symbol, uint256 _totalSupply) external returns (address);
}