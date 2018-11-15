pragma solidity >=0.4.24 <0.5.0;

import "./open-zeppelin/SafeMath.sol";

/// @title KYC Registrar
contract KYCRegistrar {

	using SafeMath for uint256;
	using SafeMath64 for uint64;

	bytes32 ownerID;

	struct Address {
		bytes32 id;
		bool restricted;
	}
	
	struct Investor {
		uint8 rating;
		bytes3 region;
		uint16 country;
		uint40 expires;
		bool restricted;
	}

	struct Authority {
		mapping (uint16 => bool) countries;
		mapping (bytes32 => address[]) multiSigAuth;
		uint64 multiSigThreshold;
		uint64 addressCount;
		bool approved;
	}

	mapping (address => Address) idMap;
	mapping (bytes32 => Investor) investorData;
	mapping (bytes32 => Authority) authorityData;

	event NewInvestor(
		bytes32 indexed id,
		uint16 indexed country,
		bytes3 region,
		uint8 rating,
		uint40 expires,
		bytes32 indexed authority
	);
	event UpdatedInvestor(
		bytes32 indexed id,
		bytes3 region,
		uint8 rating,
		uint40 expires,
		bytes32 indexed authority
	);
	event NewAuthority(bytes32 indexed id);
	event InvestorRestriction(
		bytes32 indexed id,
		bool restricted,
		bytes32 indexed authority
	);
	event NewRegisteredAddress(
		bytes32 indexed id,
		address indexed addr,
		bytes32 indexed authority
	);
	event UnregisteredAddress(
		bytes32 indexed id,
		address indexed addr,
		bytes32 indexed authority
	);


	/// @dev Checks that the calling address is associated with the owner
	modifier onlyOwner() {
		require(idMap[msg.sender].id == ownerID);
		require(!idMap[msg.sender].restricted);
		_;
	}

	/**
		@dev
	 		Checks that the calling address is associated with an authority
	 		and that the authority is approved to make changes based on the
	 		country of the investor they are updating.
		@param _id ID of investor that the authority is modifying
	 */
	modifier onlyAuthority(bytes32 _id) {
		_authorityCheck(investorData[_id].country);	
		_;
	}

	/**
		@dev Verifyies authority permission based on country
		@param _country Country relating to the authority's action
	 */
	function _authorityCheck(uint16 _country) internal view {
		bytes32 _id = idMap[msg.sender].id;
		require(_country != 0);
		require(authorityData[_id].approved);
		require(!idMap[msg.sender].restricted);
		if (_id != ownerID) {
			require(authorityData[_id].countries[_country]);
		}
	}

	/**
		@notice KYC registrar constructor
		@param _owners Array of addresses for owning authority
		@param _threshold multisig threshold for owning authority
	 */ 
	constructor (address[] _owners, uint8 _threshold) public {
		require(_threshold <= _owners.length);
		ownerID = keccak256(abi.encodePacked(address(this)));
		Authority storage a = authorityData[ownerID];
		a.approved = true;
		a.multiSigThreshold = _threshold;
		a.addressCount = uint8(_owners.length);
		_addAddresses(ownerID, _owners);
	}

	/**
		@notice Add investor to this registrar
		@dev
			Investor ID is a hash formed via a concatenation of PII
			Country and region codes are based on the ISO 3166 standard
			https://github.com/iamdefinitelyahuman/security-token/tree/master/docs/codes
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
		require(_rating > 0);
		require(_expires > now);
		require(!authorityData[_id].approved);
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

	/**
		@notice Add a new authority to this registrar
		@param _id Authority ID
		@param _addr Array of addressses to register as authority
		@param _threshold Minimum number of calls to a method for multisigk
		@return bool success
	 */
	function addAuthority(
		bytes32 _id,
		address[] _addr,
		uint8 _threshold
	)
		external
		onlyOwner
		returns (bool)
	{
		require(investorData[_id].country == 0);
		Authority storage a = authorityData[_id];
		require(!a.approved);
		require(_addr.length >= _threshold);
		if (!_checkMultiSig()) return false;
		a.approved = true;
		a.addressCount = uint8(_addr.length);
		a.multiSigThreshold = _threshold;
		emit NewAuthority(_id);
		_addAddresses(_id, _addr);
		return true;
	}

	/**
		@notice Modifies the number of calls needed by a multisig authority
		@param _id Authority ID
		@param _threshold Minimum number of calls to a method for multisig
		@return bool success
	 */
	function setAuthorityThreshold(
		bytes32 _id,
		uint8 _threshold
	)
		external
		onlyOwner
		returns (bool)
	{
		if (!_checkMultiSig()) return false;
		require(authorityData[_id].approved);
		require(_threshold <= authorityData[_id].addressCount);
		authorityData[_id].multiSigThreshold = _threshold;
		return true;
	}

	/**
		@notice Sets approval of an authority to register entities in a country
		@param _id Authority ID
		@param _countries Array of country IDs
		@param _auth boolean to set or restrict countries
		@return bool succcess
	 */
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

	/**
		@dev Internal multisig functionality
		@return bool - has call met multisig threshold?
	 */
	function _checkMultiSig() internal returns (bool) {
		bytes32 _id = idMap[msg.sender].id;
		Authority storage a = authorityData[_id];
		bytes32 _callHash = keccak256(msg.data);
		if (a.multiSigAuth[_callHash].length.add(1) >= a.multiSigThreshold) {
			delete a.multiSigAuth[_callHash];
			return true;
		}
		for (uint256 i = 0; i < a.multiSigAuth[_callHash].length; i++) {
			require(a.multiSigAuth[_callHash][i] != msg.sender);
		}
		a.multiSigAuth[_callHash].push(msg.sender);
		return false;
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
		onlyAuthority(_id)
		returns (bool)
	{
		require(investorData[_id].country != 0);
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

	/** 
		@notice Set or remove an entity's restricted status
		@dev This modifies restriciton on all addresses attached to the ID
		@param _id Entity's ID
		@param _restricted bool to allow or restrict entity
		@return bool success
	 */
	function setRestricted(
		bytes32 _id,
		bool _restricted
	)
		external
		onlyAuthority(_id)
		returns (bool)
	{	
		require(investorData[_id].country != 0);
		if (!_checkMultiSig()) return false;
		investorData[_id].restricted = _restricted;
		emit InvestorRestriction(
			_id,
			_restricted,
			idMap[msg.sender].id
		);
		return true;
	}

	/**
		@notice Register addresseses to an entity
		@param _id Entity's ID
		@param _addr Array of addresses
		@return bool success
	 */
	function registerAddresses(
		bytes32 _id,
		address[] _addr
	)
		external
		onlyAuthority(_id)
		returns (bool)
	{
		if (!_checkMultiSig()) return false;
		Authority storage a = authorityData[_id];
		if (a.approved) {
			/* Only the owner can register addresses for an authority. */
			require(idMap[msg.sender].id == ownerID);
			a.addressCount = a.addressCount.add(uint64(_addr.length));
		}
		_addAddresses(_id, _addr);
		return true;
	}

	/**
		@notice Flags addresses as restricted instead of removing them
		@dev
			Address associations can never be fully removed, only restricted.
			If an address could be fully removed it would then be possible to
			attach it to another ID, which could allow for non-compliant token
			transfers. Restricting an address cannot be undone.
		@param _addr Array of addresses
		@return bool success
	 */
	function unregisterAddress(address[] _addr) external returns (bool) {
		if (!_checkMultiSig()) return false;
		for (uint256 i = 0; i < _addr.length; i++) {
			require(idMap[_addr[i]].id != 0);
			_authorityCheck(investorData[idMap[_addr[i]].id].country);
			if (idMap[_addr[i]].id == 255) {
				/* Only the owner can unregister addresses for an authority. */
				require(idMap[msg.sender].id == ownerID);
				Authority storage a = authorityData[idMap[_addr[i]].id];
				require(a.addressCount > a.multiSigThreshold);
				a.addressCount = a.addressCount.sub(1);
			}
			idMap[_addr[i]].restricted = true;
			emit UnregisteredAddress(
				idMap[_addr[i]].id,
				_addr[i],
				idMap[msg.sender].id
			);
		}
		
		return true;
	}

	/**
		@dev adds new addresses
		@param _id investor or authority ID
		@param _addr array of addresses
	 */
	function _addAddresses(bytes32 _id, address[] _addr) internal {
		require(investorData[_id].country != 0 || authorityData[_id].approved);
		for (uint256 i = 0; i < _addr.length; i++) {
			require(idMap[_addr[i]].id == 0);
			idMap[_addr[i]].id = _id;
			emit NewRegisteredAddress(
				_id,
				_addr[i],
				idMap[msg.sender].id
			);
		}
	}

	/**
		@notice Generate a unique investor ID
		@dev https://github.com/iamdefinitelyahuman/security-token/tree/master/docs/codes/investor-id.md
		@param _idString ID string to generate hash from
		@return bytes32 investor ID hash
	 */
	function generateID(string _idString) external pure returns (bytes32) {
		return keccak256(abi.encodePacked(_idString));
	}

	/**
		@notice Fetch investor ID from an address
		@param _addr Address to query
		@return bytes32 investor ID
	 */
	function getID(address _addr) external view returns (bytes32) {
		return idMap[_addr].id;
	}

	/**
		@notice Fetch investor rating from an ID
		@param _id Investor ID
		@return uint8 rating code
	 */
	function getRating(bytes32 _id) external view returns (uint8) {
		Investor storage i = investorData[_id];
		require(i.expires >= now);
		require(i.rating > 0);
		return investorData[_id].rating;
	}

	/**
		@notice Fetch investor region from an ID
		@param _id Investor ID
		@return bytes3 region code
	 */
	function getRegion(bytes32 _id) external view returns (bytes3) {
		return investorData[_id].region;
	}

	/**
		@notice Fetch investor country from an ID
		@param _id Investor ID
		@return string
	 */
	function getCountry(bytes32 _id) external view returns (uint16) {
		return investorData[_id].country;
	}

	/**
		@notice Fetch investor KYC expiration from an ID
		@param _id Investor ID
		@return uint40 expiration epoch time
	 */
	function getExpires(bytes32 _id) external view returns (uint40) {
		return investorData[_id].expires;
	}

	/**
		@notice Fetch investor information using an address
		@dev
			This call is increases gas efficiency around token transfers
			by minimizing the amount of calls to the registrar
		@param _addr Address to query
		@return bytes32 investor ID
		@return bool are address and investor permitted?
		@return uint8 investor rating
		@return uint16 investor country code
	 */
	function getInvestor(
		address _addr
	)
		external
		view
		returns (
			bytes32 _id,
			bool _allowed,
			uint8 _rating,
			uint16 _country
		)
	{
		_id = idMap[_addr].id;
		Investor storage i = investorData[_id];
		require(i.country != 0);
		return (
			_id,
			!i.restricted && i.expires > now && !idMap[_addr].restricted,
			i.rating,
			i.country
		);
	}

	/**
		@notice Use addresses to fetch information on 2 investors
		@dev
			This call is increases gas efficiency around token transfers
			by minimizing the amount of calls to the registrar.
		@param _addr array of addresses to query
		@return bytes32 array of investor ID
		@return bool array - investors are permitted?
		@return uint8 array of investor ratings
		@return uint16 array of investor country codes
	 */
	function getInvestors(
		address _from,
		address _to
	)
		external
		view
		returns (
			bytes32[2] _id,
			bool[2] _allowed,
			uint8[2] _rating,
			uint16[2] _country
		)
	{
		Investor storage f = investorData[idMap[_from].id];
		require(f.country != 0);
		Investor storage t = investorData[idMap[_to].id];
		require(t.country != 0);
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
	
	/**
		@notice Check if an an investor and address are permitted
		@dev This function will throw rather than returning false
		@param _addr Address to query
		@return bool success
	 */
	function isPermitted(address _addr) external view returns (bool) {
		require(!idMap[_addr].restricted);
		require(!investorData[idMap[_addr].id].restricted);
		require(investorData[idMap[_addr].id].country != 0);
		return true;
	}

}
