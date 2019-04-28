pragma solidity >=0.4.24 <0.5.0;

import "./bases/KYC.sol";
import "./bases/MultiSig.sol";

/** @title Simplified KYC Contract for Single Issuer */
contract KYCIssuer is KYCBase {

	MultiSig public issuer;

	/**
		@notice KYC registrar constructor
		@param _issuer IssuingEntity contract address
	 */
	constructor (MultiSig _issuer) public {
		issuer = _issuer;
	}

	/**
		@notice Check that the call originates from an approved authority
		@return bool success
	 */
	function _onlyAuthority() internal returns (bool) {
		return issuer.checkMultiSigExternal(
			msg.sender,
			keccak256(msg.data),
			msg.sig
		);
	}

	/**
		@notice Internal function to add new addresses
		@param _id investor or authority ID
		@param _addr array of addresses
	 */
	function _addAddresses(bytes32 _id, address[] _addr) internal {
		for (uint256 i; i < _addr.length; i++) {
			Address storage _inv = idMap[_addr[i]];
			/** If address was previous assigned to this investor ID
				and is currently restricted - remove the restriction */
			if (_inv.id == _id && _inv.restricted) {
				_inv.restricted = false;
			/* If address has not had an investor ID associated - set the ID */
			} else if (_inv.id == 0) {
				require(!issuer.isAuthority(_addr[i]), "dev: auth address");
				_inv.id = _id;
			/* In all other cases, revert */
			} else {
				revert("dev: known address");
			}
		}
		emit RegisteredAddresses(_id, _addr, issuer.getID(msg.sender));
	}

	/**
		@notice Add investor to this registrar
		@dev
			Investor ID is a hash formed via a concatenation of PII
			Country and region codes are based on the ISO 3166 standard
			https://sft-protocol.readthedocs.io/en/latest/data-standards.html
		@param _id Investor ID
		@param _country Investor country code
		@param _region Investor region code
		@param _rating Investor rating (accreditted, qualified, etc)
		@param _expires Registry expiration in epoch time
		@param _addr Array of addresses to register to investor
		@return bool success
	*/
	function addInvestor(
		bytes32 _id,
		uint16 _country,
		bytes3 _region,
		uint8 _rating,
		uint40 _expires,
		address[] _addr
	 )
		external
		returns (bool)
	{
		if (!_onlyAuthority()) return false;
		require(!issuer.isAuthorityID(_id), "dev: authority ID");
		require(investorData[_id].country == 0, "dev: investor ID");
		require(_country > 0, "dev: country 0");
		_setInvestor(0x00, _id, _country, _region, _rating, _expires);
		emit NewInvestor(
			_id,
			_country,
			_region,
			_rating,
			_expires,
			issuer.getID(msg.sender)
		);
		_addAddresses(_id, _addr);
		return true;
	}

	/**
		@notice Update an investor
		@dev Investor country may not be changed as this will alter their ID
		@param _id Investor ID
		@param _region Investor region
		@param _rating Investor rating
		@param _expires Registry expiration in epoch time
		@return bool success
	 */
	function updateInvestor(
		bytes32 _id,
		bytes3 _region,
		uint8 _rating,
		uint40 _expires
	)
		external
		returns (bool)
	{
		if (!_onlyAuthority()) return false;
		require(investorData[_id].country != 0, "dev: unknown ID");
		_setInvestor(0x00, _id, 0, _region, _rating, _expires);
		emit UpdatedInvestor(
			_id,
			_region,
			_rating,
			_expires,
			issuer.getID(msg.sender)
		);
		return true;
	}

	/**
		@notice Set or remove an investor's restricted status
		@dev This modifies restriciton on all addresses attached to the ID
		@param _id Investor ID
		@param _permitted Permission bool
		@return bool success
	 */
	function setInvestorRestriction(
		bytes32 _id,
		bool _permitted
	)
		external
		returns (bool)
	{
		if (!_onlyAuthority()) return false;
		require(investorData[_id].country != 0);
		investorData[_id].restricted = !_permitted;
		emit InvestorRestriction(_id, _permitted, issuer.getID(msg.sender));
		return true;
	}

	/**
		@notice Register addresseses to an entity
		@dev
			Can be used to add new addresses or remove restrictions
			from already associated addresses
		@param _id Entity's ID
		@param _addr Array of addresses
		@return bool success
	 */
	function registerAddresses(
		bytes32 _id,
		address[] _addr
	)
		external
		returns (bool)
	{
		if (!_onlyAuthority()) return false;
		_addAddresses(_id, _addr);
		return true;
	}

	/**
		@notice Flags addresses as restricted instead of removing them
		@dev
			Address associations can only be restricted, never fully removed.
			If an association were removed it would then be possible to attach
			the address to another ID which could allow for non-compliant token
			transfers.
		@param _id Entity ID
		@param _addr Array of addresses
		@return bool success
	 */
	function restrictAddresses(
		bytes32 _id,
		address[] _addr
	)
		external
		returns (bool) 
	{
		if (!_onlyAuthority()) return false;
		for (uint256 i; i < _addr.length; i++) {
			require(idMap[_addr[i]].id == _id, "dev: wrong ID");
			require(!idMap[_addr[i]].restricted, "dev: already restricted");
			idMap[_addr[i]].restricted = true;
		}
		emit RestrictedAddresses(_id, _addr, issuer.getID(msg.sender));
		return true;
	}

	/**
		@notice Check if an an investor is permitted based on ID
		@param _id Investor ID to query
		@return bool permission
	 */
	function isPermittedID(bytes32 _id) public view returns (bool) {
		Investor storage i = investorData[_id];
		if (i.restricted) return false;
		if (i.expires < now) return false;
		return true;
	}

}
