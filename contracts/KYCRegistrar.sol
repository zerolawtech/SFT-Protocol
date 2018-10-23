pragma solidity ^0.4.24;

import "./open-zeppelin/SafeMath.sol";

/// @title KYC Registrar
contract KYCRegistrar {

	using SafeMath for uint256;

	bytes32 ownerID;

	struct Address {
		bytes32 id;
		bool restricted;
	}
	
	/*
		Investor accreditation levels:
			1 - unaccredited
			2 - accredited
			3 - qualified
	*/
	struct Investor {
		uint8 rating;
		uint16 region;
		uint16 country;
		uint40 expires;
		bool restricted;
	}

	struct Authority {
		mapping (uint16 => bool) countries;
		mapping (bytes32 => address[]) multiSigAuth;
		uint8 multiSigThreshold;
		uint8 addressCount;
		bool approved;
	}

	mapping (address => Address) idMap;
	mapping (bytes32 => Investor) investorData;
	mapping (bytes32 => Authority) authorityData;

	event NewInvestor(
		bytes32 id,
		uint16 country,
		uint16 region,
		uint8 rating,
		uint40 expires,
		bytes32 authority
	);
	event UpdatedInvestor(
		bytes32 id,
		uint16 region,
		uint8 rating,
		uint40 expires,
		bytes32 authority
	);
	event NewAuthority(bytes32 id);
	event InvestorRestriction(
		bytes32 id,
		bool restricted,
		bytes32 authority
	);
	event NewRegisteredAddress(
		bytes32 id,
		address addr,
		bytes32 authority
	);
	event UnregisteredAddress(
		bytes32 id,
		address addr,
		bytes32 authority
	);

	modifier onlyOwner() {
		require (idMap[msg.sender].id == ownerID);
		require (!idMap[msg.sender].restricted);
		_;
	}

	modifier onlyAuthority(uint16 _country) {
		_authorityCheck(idMap[msg.sender].id, _country);
		_;
	}

	modifier onlyAuthorityByID(bytes32 _id) {
		_authorityCheck(idMap[msg.sender].id, investorData[_id].country);	
		_;
	}

	function _authorityCheck(bytes32 _id, uint16 _country) internal view {
		require (_country != 0);
		require (authorityData[_id].approved);
		require (!idMap[msg.sender].restricted);
		if (_id != ownerID) {
			require (authorityData[_id].countries[_country]);
		}
	}

	/// @notice KYC registrar constructor
	/// @param _owners Array of addresses for owning authority
	/// @param _id ID of owning authority
	/// @param _threshold multisig threshold for owning authority
	constructor (address[] _owners, bytes32 _id, uint8 _threshold) public {
		require (_threshold <= _owners.length);
		ownerID = _id;
		Authority storage a = authorityData[ownerID];
		a.approved = true;
		a.multiSigThreshold = _threshold;
		a.addressCount = uint8(_owners.length);
		_addAddresses(ownerID, _owners);
	}

	/// @notice Add investor to this registrar
	/// @param _id A hash of (_fullName, _ddmmyyyy, _taxID)
	/// @param _country Investor's country
	/// @param _region Specific region in investor's country
	/// @param _rating Unaccredited, accredited, qualified
	/// @param _expires Registry expiration, epoch time
	/// @param _addr Array of addresses to register as investor
	/// @return bool
	function addInvestor(
		bytes32 _id,
		uint16 _country,
		uint16 _region,
		uint8 _rating,
		uint40 _expires,
		address[] _addr
	 )
		external
		onlyAuthority(_country)
		returns (bool)
	{
		require (_rating > 0);
		require (_expires > now);
		require (!authorityData[_id].approved);
		if (!_checkMultiSig()) return false;
		Investor storage i = investorData[_id];
		i.rating = _rating;
		i.region = _region;
		i.country = _country;
		i.expires = _expires;
		emit NewInvestor(
			_id, 
			_country, 
			_region,
			_rating, 
			_expires,
			idMap[msg.sender].id
		);
		_addAddresses(_id, _addr);
		return true;
	}

	/// @notice Add a new authority to this registrar
	/// @param _id Authority ID
	/// @param _addr Array of addressses to register as authority
	/// @param _threshold Minimum number of calls to a method for multisigk
	/// @return bool
	function addAuthority(
		bytes32 _id,
		address[] _addr,
		uint8 _threshold
	)
		external
		onlyOwner
		returns (bool)
	{
		require (investorData[_id].country == 0);
		Authority storage a = authorityData[_id];
		require (!a.approved);
		require (_addr.length >= _threshold);
		if (!_checkMultiSig()) return false;
		a.approved = true;
		a.addressCount = uint8(_addr.length);
		a.multiSigThreshold = _threshold;
		emit NewAuthority(_id);
		_addAddresses(_id, _addr);
		return true;
	}

	/// @notice Modifies the number of calls needed by a multisig authority
	/// @param _id Authority ID
	/// @param _threshold Minimum number of calls to a method for multisigk
	/// @return bool
	function setAuthorityThreshold(
		bytes32 _id,
		uint8 _threshold
	)
		external
		onlyOwner
		returns (bool)
	{
		if (!_checkMultiSig()) return false;
		require (authorityData[_id].approved);
		require (_threshold <= authorityData[_id].addressCount);
		authorityData[_id].multiSigThreshold = _threshold;
		return true;
	}

	/// @notice Sets approval of an authority to register entities in a country
	/// @param _id Authority ID
	/// @param _countries Array of country IDs
	/// @param _auth boolean to set or restrict countries
	/// @return bool
	function setAuthorityCountries(
		bytes32 _id,
		uint16[] _countries,
		bool _auth
	)
		external
		onlyOwner
		returns (bool)
	{
		if (!_checkMultiSig()) return false;
		Authority storage a = authorityData[_id];
		require(a.approved);
		for (uint256 i = 0; i < _countries.length; i++) {
			a.countries[_countries[i]] = _auth;
		}
		return true;
	}

	function _checkMultiSig() internal returns (bool) {
		bytes32 _id = idMap[msg.sender].id;
		Authority storage a = authorityData[_id];
		bytes32 _callHash = keccak256(msg.data);
		if (a.multiSigAuth[_callHash].length.add(1) >= a.multiSigThreshold) {
			delete a.multiSigAuth[_callHash];
			return true;
		}
		for (uint256 i = 0; i < a.multiSigAuth[_callHash].length; i++) {
			require (a.multiSigAuth[_callHash][i] != msg.sender);
		}
		a.multiSigAuth[_callHash].push(msg.sender);
		return false;
	}

	/// @notice Update an investor
	/// @param _id Investor ID
	/// @param _region Investor's region
	/// @param _rating Investor's rating
	/// @param _expires Registry expiration
	/// @return bool
	function updateInvestor(
		bytes32 _id,
		uint16 _region,
		uint8 _rating,
		uint40 _expires
	)
		external
		onlyAuthorityByID(_id)
		returns (bool)
	{
		require (investorData[_id].country != 0);
		if (!_checkMultiSig()) return false;
		investorData[_id].region = _region;
		investorData[_id].rating = _rating;
		investorData[_id].expires = _expires;
		emit UpdatedInvestor(
			_id,
			_region,
			_rating,
			_expires,
			idMap[msg.sender].id
		);
		return true;
	}

	/// @notice Set or remove an entity's restricted status
	/// @dev This modifes restriction on the entire entity, not a single address
	/// @param _id Entity's ID
	/// @param _restricted boolean
	/// @return bool
	function setRestricted(
		bytes32 _id,
		bool _restricted
	)
		external
		onlyAuthorityByID(_id)
		returns (bool)
	{
		
		require (investorData[_id].country != 0);
		if (!_checkMultiSig()) return false;
		investorData[_id].restricted = _restricted;
		emit InvestorRestriction(
			_id,
			_restricted,
			idMap[msg.sender].id
		);
		return true;
	}

	/// @notice Register addresseses to an entity
	/// @param _id Entity's ID
	/// @param _addr Array of addresses
	/// @return bool
	function registerAddresses(
		bytes32 _id,
		address[] _addr
	)
		external
		onlyAuthorityByID(_id)
		returns (bool)
	{
		if (!_checkMultiSig()) return false;
		if (authorityData[_id].approved) {
			/*
				Only the owner can register addresses for an authority.
			*/
			require (idMap[msg.sender].id == ownerID);
			require (
				authorityData[_id].addressCount + _addr.length >
				authorityData[_id].addressCount
			);
			authorityData[_id].addressCount += uint8(_addr.length);
		}
		_addAddresses(_id, _addr);
		return true;
	}

	/// @notice Flags an address as restricted instead of removing it
	/// @dev Address associations can never be fully removed, only restricted.
	/// This action cannot be reversed.
	/// @param _addr Entity's address
	/// @return bool
	function unregisterAddress(address _addr) external returns (bool) {
		require (idMap[_addr].id != 0);
		_authorityCheck(
			idMap[msg.sender].id,
			investorData[idMap[_addr].id].country
		);
		if (!_checkMultiSig()) return false;
		if (idMap[_addr].id == 255) {
			/*
				If the address is associated with an authority, only the
				owner can unregister it.
			*/
			require (idMap[msg.sender].id == ownerID);
			bytes32 _id = idMap[_addr].id;
			require (authorityData[_id].addressCount > 1);
			require (
				authorityData[_id].addressCount > 
				authorityData[_id].multiSigThreshold
			);
			authorityData[_id].addressCount -= 1;
		}
		idMap[_addr].restricted = true;
		emit UnregisteredAddress(
			idMap[_addr].id,
			_addr,
			idMap[msg.sender].id
		);
		return true;
	}

	function _addAddresses(bytes32 _id, address[] _addr) internal {
		require (investorData[_id].country != 0 || authorityData[_id].approved);
		for (uint256 i = 0; i < _addr.length; i++) {
			require (idMap[_addr[i]].id == 0);
			idMap[_addr[i]].id = _id;
			emit NewRegisteredAddress(
				_id,
				_addr[i],
				idMap[msg.sender].id
			);
		}
	}

	/// @notice Generate a unique investor ID
	/// @param _idString ID string that hash is generated from
	/// @return bytes32
	function generateId(string _idString) external pure returns (bytes32) {
		return keccak256(abi.encodePacked(_idString));
	}

	/// @notice Fetch ID from an address
	/// @param _addr Address to query
	/// @return string
	function getId(address _addr) external view returns (bytes32) {
		return idMap[_addr].id;
	}

	/// @notice Fetch investor from an ID
	/// @param _id Investor's ID
	/// @return Array of (country, region, rating, expires)
	function getInvestor(
		bytes32 _id
	)
		external
		view
		returns (
			uint16 _country,
			uint16 _region,
			uint8 _rating,
			uint40 _expires
		)
	{
		require (investorData[_id].country != 0);
		return (
			investorData[_id].country,
			investorData[_id].region,
			investorData[_id].rating,
			investorData[_id].expires
		);
	}

	/// @notice Fetch rating of an entity
	/// @param _id Entity's ID
	/// @return integer
	function getRating(bytes32 _id) external view returns (uint8) {
		Investor storage i = investorData[_id];
		require (i.expires >= now);
		require (i.rating > 0);
		return investorData[_id].rating;
	}

	/// @notice Fetch region from an entity
	/// @param _id Entity's ID
	/// @return string
	function getRegion(bytes32 _id) external view returns (uint16) {
		return investorData[_id].region;
	}

	/// @notice Fetch KYC expiry date of an entity
	/// @param _id Entity's ID
	/// @return integer
	function getExpires(bytes32 _id) external view returns (uint40) {
		return investorData[_id].expires;
	}

	/// @notice Fetch country from an entity
	/// @param _id Entity's ID
	/// @return string
	function getCountry(bytes32 _id) external view returns (uint16) {
		return investorData[_id].country;
	}

	function getInvestor(
		address _addr
	)
		external
		view
		returns
	(
		bytes32 _id,
		bool _allowed,
		uint8 _rating,
		uint16 _country
	) {
		_id = idMap[_addr].id;
		Investor storage i = investorData[_id];
		require (i.country != 0);
		return (
			_id,
			!i.restricted && i.expires > now && !idMap[_addr].restricted,
			i.rating,
			i.country
		);
	}

	function getInvestors(
		address _from,
		address _to
	)
		external
		view
		returns
	(
		
		bytes32[2] _id,
		bool[2] _allowed,
		uint8[2] _rating,
		uint16[2] _country
	) {
		Investor storage f = investorData[idMap[_from].id];
		require (f.country != 0);
		Investor storage t = investorData[idMap[_to].id];
		require (t.country != 0);
		return (
			bytes32[2]([idMap[_from].id, idMap[_to].id]),
			bool[2]([
				!f.restricted && f.expires > now && !idMap[_from].restricted,
				!t.restricted && t.expires > now && !idMap[_to].restricted
			]),
			uint8[2]([f.rating,t.rating]),
			uint16[2]([f.country, t.country])
		);
	}

	function isPermitted(address _addr) external view returns (bool) {
		require (!idMap[_addr].restricted);
		require (!investorData[idMap[_addr].id].restricted);
		require (investorData[idMap[_addr].id].country != 0);
		return true;
	}

}
