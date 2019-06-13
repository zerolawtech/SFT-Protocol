pragma solidity >=0.4.24 <0.5.0;

import "./bases/KYC.sol";

/** @title KYC Registrar */
contract KYCRegistrar is KYCBase {

	bytes32 ownerID;

	struct Authority {
		mapping (bytes32 => address[]) multiSigAuth;
		uint256[4] countries;
		uint32 multiSigThreshold;
		uint32 addressCount;
		bool restricted;
	}

	mapping (bytes32 => Authority) authorityData;

	event NewAuthority(bytes32 indexed id);
	event AuthorityRestriction(bytes32 indexed id, bool restricted);
	event MultiSigCall(
		bytes32 indexed id,
		bytes4 indexed callSignature,
		bytes32 indexed callHash,
		address caller,
		uint256 callCount,
		uint256 threshold
	);
	event MultiSigCallApproved(
		bytes32 indexed id,
		bytes4 indexed callSignature,
		bytes32 indexed callHash,
		address caller
	);

	/**
		@notice KYC registrar constructor
		@param _owners Array of addresses for owning authority
		@param _threshold multisig threshold for owning authority
	 */
	constructor (address[] _owners, uint32 _threshold) public {
		require(_threshold > 0);
		require(_threshold <= _owners.length);
		ownerID = keccak256(abi.encodePacked(address(this)));
		Authority storage a = authorityData[ownerID];
		a.multiSigThreshold = _threshold;
		a.addressCount = uint32(_owners.length);
		_addAddresses(ownerID, _owners);
	}

	/**
		@notice Internal multisig functionality
		@param _onlyOwner is the call only possible via the owning authority?
		@return bool - has call met multisig threshold?
	 */
	function _checkMultiSig(bool _onlyOwner) internal returns (bool) {
		bytes32 _id = idMap[msg.sender].id;
		if (_onlyOwner) {
			require(_id == ownerID); // dev: only owner
			require(!idMap[msg.sender].restricted); // dev: restricted owner
		}
		Authority storage a = authorityData[_id];
		bytes32 _callHash = keccak256(msg.data);
		for (uint256 i; i < a.multiSigAuth[_callHash].length; i++) {
			require(a.multiSigAuth[_callHash][i] != msg.sender); // dev: repeat caller
		}
		if (a.multiSigAuth[_callHash].length + 1 >= a.multiSigThreshold) {
			delete a.multiSigAuth[_callHash];
			emit MultiSigCallApproved(_id, msg.sig, _callHash, msg.sender);
			return true;
		}
		a.multiSigAuth[_callHash].push(msg.sender);
		emit MultiSigCall(
			_id, 
			msg.sig,
			_callHash,
			msg.sender,
			a.multiSigAuth[_callHash].length,
			a.multiSigThreshold
		);
		return false;
	}

	/**
		@notice Verifyies authority permission based on country
		@param _country Country relating to the authority's action
	 */
	function _authorityCheck(uint16 _country) internal view {
		bytes32 _id = idMap[msg.sender].id;
		require(_country != 0); // dev: country 0
		Authority storage a = authorityData[_id];
		require(!a.restricted); // dev: restricted ID
		require(!idMap[msg.sender].restricted); // dev: restricted address
		if (_id == ownerID) return;
		uint256 _idx = _country / 256;
		require(a.countries[_idx] >> (_country - _idx * 256) & uint256(1) == 1); // dev: country
	}

	/**
		@notice Internal function to add new addresses
		@param _id investor or authority ID
		@param _addr array of addresses
		@return number of new addresses (not previously restricted)
	 */
	function _addAddresses(
		bytes32 _id,
		address[] _addr
	)
		internal
		returns (uint32 _count) 
	{
		for (uint256 i; i < _addr.length; i++) {
			Address storage _inv = idMap[_addr[i]];
			/** If address was previous assigned to this investor ID
				and is currently restricted - remove the restriction */
			if (_inv.id == _id && _inv.restricted) {
				_inv.restricted = false;
			/* If address has not had an investor ID associated - set the ID */
			} else if (_inv.id == 0) {
				_inv.id = _id;
				_count++;
			/* In all other cases, revert */
			} else {
				revert(); // dev: known address
			}
		}
		emit RegisteredAddresses(_id, _addr, idMap[msg.sender].id);
		return _count;
	}

	/**
		@notice Internal function set authority country booleans
		@param _countries Storage pointer to authority country bit field
		@param _toSet Array of country codes
		@param _permitted Boolean to set countries to
	 */
	function _setCountries(
		uint256[4] storage _countries,
		uint16[] memory _toSet,
		bool _permitted
	)
		internal
	{
		uint256[4] memory _bitfield = _countries;
		for (uint256 i; i < _toSet.length; i++) {
			uint256 _idx = _toSet[i] / 256;
			if (_permitted) {
				_bitfield[_idx] = (
					_bitfield[_idx] | uint256(1) <<
					(_toSet[i] - _idx*256)
				);
			} else {
				_bitfield[_idx] = (
					_bitfield[_idx] & ~(uint256(1) <<
					(_toSet[i] - _idx*256))
				);
			}
		}
		for (i = 0; i < 4; i++) {
			if (_bitfield[i] != _countries[i]) {
				_countries[i] = _bitfield[i];
			}
		}
	}

	/**
		@notice Add a new authority to this registrar
		@param _addr Array of addressses to register as authority
		@param _countries Array of country codes the authority is approved for
		@param _threshold Minimum number of calls to a method for multisig
		@return bool success
	 */
	function addAuthority(
		address[] _addr,
		uint16[] _countries,
		uint32 _threshold
	)
		external
		returns (bool)
	{
		if (!_checkMultiSig(true)) return false;
		require(_threshold > 0); // dev: zero threshold
		bytes32 _authID = keccak256(abi.encodePacked(address(this), _addr[0]));
		require(investorData[_authID].authority == 0); // dev: investor ID
		Authority storage a = authorityData[_authID];
		require(a.addressCount == 0); // dev: authority exists
		a.addressCount = _addAddresses(_authID, _addr);
		require(a.addressCount >= _threshold); // dev: threshold too high
		a.multiSigThreshold = _threshold;
		_setCountries(a.countries, _countries, true);
		emit NewAuthority(_authID);
		return true;
	}

	/**
		@notice Modifies the number of calls needed by a multisig authority
		@param _authID Authority ID
		@param _threshold Minimum number of calls to a method for multisig
		@return bool success
	 */
	function setAuthorityThreshold(
		bytes32 _authID,
		uint32 _threshold
	)
		external
		returns (bool)
	{
		if (!_checkMultiSig(true)) return false;
		require(_threshold > 0); // dev: zero threshold
		require(authorityData[_authID].addressCount > 0); // dev: not authority
		require(_threshold <= authorityData[_authID].addressCount); // dev: threshold too high
		authorityData[_authID].multiSigThreshold = _threshold;
		return true;
	}

	/**
		@notice Sets approval of an authority to register entities in a country
		@param _authID Authority ID
		@param _countries Array of country IDs
		@param _permitted boolean to set or restrict countries
		@return bool succcess
	 */
	function setAuthorityCountries(
		bytes32 _authID,
		uint16[] _countries,
		bool _permitted
	)
		external
		returns (bool)
	{
		if (!_checkMultiSig(true)) return false;
		Authority storage a = authorityData[_authID];
		require(a.addressCount > 0); // dev: not authority
		_setCountries(a.countries, _countries, _permitted);
		return true;
	}

	/**
		@notice Set or remove an authority's restricted status
		@dev
			Restricting an authority will also restrict every investor that
			was approved by that authority.
		@param _authID Authority ID
		@param _restricted Permission bool
		@return bool success
	 */
	function setAuthorityRestriction(
		bytes32 _authID,
		bool _restricted
	)
		external
		returns (bool)
	{
		if (!_checkMultiSig(true)) return false;
		require(_authID != ownerID); // dev: owner
		require(authorityData[_authID].addressCount > 0); // dev: not authority
		authorityData[_authID].restricted = _restricted;
		emit AuthorityRestriction(_authID, _restricted);
		return true;
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
		_authorityCheck(_country);
		require(authorityData[_id].addressCount == 0); // dev: authority ID
		require(investorData[_id].authority == 0); // dev: investor ID
		if (!_checkMultiSig(false)) return false;
		bytes32 _authID = idMap[msg.sender].id;
		_setInvestor(_authID, _id, _country, _region, _rating, _expires);
		emit NewInvestor(_id, _country, _region, _rating, _expires, _authID);
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
		_authorityCheck(investorData[_id].country);
		if (!_checkMultiSig(false)) return false;
		bytes32 _authID = idMap[msg.sender].id;
		_setInvestor(_authID, _id, 0, _region, _rating, _expires);
		emit UpdatedInvestor(_id, _region, _rating, _expires, _authID);
		return true;
	}

	/**
		@notice Set or remove an investor's restricted status
		@dev This modifies restriciton on all addresses attached to the ID
		@param _id Investor ID
		@param _restricted Permission bool
		@return bool success
	 */
	function setInvestorRestriction(
		bytes32 _id,
		bool _restricted
	)
		external
		returns (bool)
	{
		_authorityCheck(investorData[_id].country);
		if (!_checkMultiSig(false)) return false;
		investorData[_id].restricted = _restricted;
		emit InvestorRestriction(_id, _restricted, idMap[msg.sender].id);
		return true;
	}

	/**
		@notice Modify an investor's registering authority
		@dev
			This function is used by the owner to reassign investors to an
			unrestricted authority if their original authority was restricted.
		@param _authID Authority ID
		@param _id Investor ID
		@return bool success
	 */
	function setInvestorAuthority(
		bytes32 _authID,
		bytes32[] _id
	)
		external
		returns (bool)
	{
		require(authorityData[_authID].addressCount > 0); // dev: not authority
		if (!_checkMultiSig(true)) return false;
		for (uint256 i; i < _id.length; i++) {
			require(investorData[_id[i]].country != 0); // dev: unknown ID
			Investor storage inv = investorData[_id[i]];
			inv.authority = _authID;
			emit UpdatedInvestor(
				_id[i],
				inv.region,
				inv.rating,
				inv.expires,
				_authID
			);
		}
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
		if (!_checkMultiSig(false)) return false;
		Authority storage a = authorityData[_id];
		if (a.addressCount > 0) {
			/* Only the owner can register addresses for an authority. */
			require(idMap[msg.sender].id == ownerID); // dev: not owner
			require(!idMap[msg.sender].restricted); // dev: restricted address
			a.addressCount += _addAddresses(_id, _addr);
		} else {
			_authorityCheck(investorData[_id].country);
			_addAddresses(_id, _addr);
		}
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
		if (!_checkMultiSig(false)) return false;
		if (authorityData[_id].addressCount > 0) {
			/* Only the owner can unregister addresses for an authority. */
			require(idMap[msg.sender].id == ownerID); // dev: not owner
			Authority storage a = authorityData[_id];
			require(a.addressCount >= _addr.length); // dev: addressCount underflow
			a.addressCount -= uint32(_addr.length);
			require(a.addressCount >= a.multiSigThreshold); // dev: below threshold
		} else {
			_authorityCheck(investorData[_id].country);
		}
		for (uint256 i; i < _addr.length; i++) {
			require(idMap[_addr[i]].id == _id); // dev: wrong ID
			require(!idMap[_addr[i]].restricted); // dev: already restricted
			idMap[_addr[i]].restricted = true;
		}
		emit RestrictedAddresses(_id, _addr, idMap[msg.sender].id);
		return true;
	}

	/**
		@notice Fetch the ID of an authority
		@param _addr Authority address
		@return bytes32 Authority ID
	 */
	function getAuthorityID(address _addr) external view returns (bytes32 _authID) {
		_authID = idMap[_addr].id;
		require (authorityData[_authID].addressCount > 0);
		return _authID;
	}

	/**
		@notice Check address belongs to an authority approved for a country
		@param _addr Authority address
		@param _country Country code
		@return bool approval
	 */
	function isApprovedAuthority(
		address _addr,
		uint16 _country
	)
		external
		view
		returns (bool)
	{
		if (_country == 0) return false;
		if (idMap[_addr].restricted) return false;
		bytes32 _id = idMap[_addr].id;
		if (_id == ownerID) return true;
		Authority storage a = authorityData[_id];
		if (a.restricted) return false;
		uint256 _idx = _country / 256;
		return a.countries[_idx] >> (_country - _idx * 256) & uint256(1) == 1;
	}

	/**
		@notice Check if an an investor is permitted based on ID
		@param _id Investor ID to query
		@return bool permission
	 */
	function isPermittedID(bytes32 _id) public view returns (bool) {
		Investor storage i = investorData[_id];
		if (authorityData[i.authority].restricted) return false;
		if (i.restricted) return false;
		if (i.expires < now) return false;
		return true;
	}

}
