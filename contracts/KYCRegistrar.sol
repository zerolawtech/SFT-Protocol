pragma solidity >=0.4.24 <0.5.0;

import "./open-zeppelin/SafeMath.sol";

/** @title KYC Registrar */
contract KYCRegistrar {

	using SafeMath for uint256;
	using SafeMath32 for uint32;

	bytes32 ownerID;

	struct Address {
		bytes32 id;
		bool restricted;
	}

	struct Investor {
		bytes32 authority;
		bytes3 region;
		uint8 rating;
		uint16 country;
		uint40 expires;
		bool restricted;
	}

	struct Authority {
		mapping (uint16 => bool) countries;
		mapping (bytes32 => address[]) multiSigAuth;
		uint32 multiSigThreshold;
		uint32 addressCount;
		bool restricted;
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
	event AuthorityRestriction(bytes32 indexed id, bool permitted);
	event InvestorRestriction(
		bytes32 indexed id,
		bool restricted,
		bytes32 indexed authority
	);
	event RegisteredAddresses(
		bytes32 indexed id,
		address[] addr,
		bytes32 indexed authority
	);
	event RestrictedAddresses(
		bytes32 indexed id,
		address[] addr,
		bytes32 indexed authority
	);


	/** @dev Checks that the calling address is associated with the owner */
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
		@notice KYC registrar constructor
		@param _owners Array of addresses for owning authority
		@param _threshold multisig threshold for owning authority
	 */
	constructor (address[] _owners, uint8 _threshold) public {
		require(_threshold <= _owners.length);
		ownerID = keccak256(abi.encodePacked(address(this)));
		Authority storage a = authorityData[ownerID];
		a.multiSigThreshold = _threshold;
		a.addressCount = uint32(_owners.length);
		_addAddresses(ownerID, _owners);
	}

	/**
		@notice Internal multisig functionality
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
		@notice Verifyies authority permission based on country
		@param _country Country relating to the authority's action
	 */
	function _authorityCheck(uint16 _country) internal view {
		bytes32 _id = idMap[msg.sender].id;
		require(_country != 0);
		require(authorityData[_id].addressCount > 0);
		require(!authorityData[_id].restricted);
		require(!idMap[msg.sender].restricted);
		if (_id != ownerID) {
			require(authorityData[_id].countries[_country]);
		}
	}

	/**
		@notice Internal function to add new addresses
		@param _id investor or authority ID
		@param _addr array of addresses
	 */
	function _addAddresses(bytes32 _id, address[] _addr) internal {
		require(
			investorData[_id].country != 0 ||
			authorityData[_id].addressCount > 0
		);
		for (uint256 i = 0; i < _addr.length; i++) {
			if (idMap[_addr[i]].id == _id && idMap[_addr[i]].restricted) {
				idMap[_addr[i]].restricted = false;
			} else if (idMap[_addr[i]].id == 0) {
				idMap[_addr[i]].id = _id;
			} else {
				revert();
			}
		}
		emit RegisteredAddresses(_id, _addr, idMap[msg.sender].id);
	}

	/**
		@notice Add a new authority to this registrar
		@param _addr Array of addressses to register as authority
		@param _threshold Minimum number of calls to a method for multisigk
		@return bool success
	 */
	function addAuthority(
		address[] _addr,
		uint16[] _countries,
		uint8 _threshold
	)
		external
		onlyOwner
		returns (bool)
	{
		bytes32 _id = keccak256(abi.encodePacked(address(this),_addr[0]));
		require(investorData[_id].country == 0);
		Authority storage a = authorityData[_id];
		require(authorityData[_id].addressCount == 0);
		require(_addr.length >= _threshold);
		if (!_checkMultiSig()) return false;
		a.addressCount = uint8(_addr.length);
		a.multiSigThreshold = _threshold;
		_addAddresses(_id, _addr);
		for (uint256 i = 0; i < _countries.length; i++) {
			a.countries[_countries[i]] = true;
		}
		emit NewAuthority(_id);
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
		require(authorityData[_id].addressCount > 0);
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
		require(authorityData[_id].addressCount > 0);
		for (uint256 i = 0; i < _countries.length; i++) {
			a.countries[_countries[i]] = _auth;
		}
		return true;
	}

	/**
		@notice Set or remove an authority's restricted status
		@dev
			Restricting an authority will also restrict every investor that
			was approved by that authority.
		@param _id Authority ID
		@param _permitted Permission bool
		@return bool success
	 */
	function setAuthorityRestriction(
		bytes32 _id,
		bool _permitted
	)
		external
		onlyOwner
		returns (bool)
	{
		require(authorityData[_id].addressCount > 0);
		if (!_checkMultiSig()) return false;
		authorityData[_id].restricted = !_permitted;
		emit AuthorityRestriction(_id, !_permitted);
		return true;
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
		require(authorityData[_id].addressCount == 0);
		if (!_checkMultiSig()) return false;
		investorData[_id] = Investor(
			idMap[msg.sender].id,
			_region,
			_rating,
			_country,
			_expires,
			false
		);
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
		investorData[_id].authority = idMap[msg.sender].id;
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
		onlyAuthority(_id)
		returns (bool)
	{
		require(investorData[_id].country != 0);
		if (!_checkMultiSig()) return false;
		investorData[_id].restricted = !_permitted;
		emit InvestorRestriction(_id, !_permitted, idMap[msg.sender].id);
		return true;
	}

	/**
		@notice Modify an investor's registering authority
		@dev
			This function is used by the owner to reassign investors to an
			unrestricted authority if their original authority was restricted.
		@param _id Investor ID
		@param _authID Authority ID
		@return bool success
	 */
	function setInvestorAuthority(
		bytes32[] _id,
		bytes32 _authID
	)
		external
		onlyOwner
		returns (bool)
	{
		require(authorityData[_authID].addressCount > 0);
		if (!_checkMultiSig()) return false;
		for (uint256 i = 0; i < _id.length; i++) {
			require(investorData[_id[i]].country != 0);
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
		if (!_checkMultiSig()) return false;
		Authority storage a = authorityData[_id];
		if (a.addressCount > 0) {
			/* Only the owner can register addresses for an authority. */
			require(idMap[msg.sender].id == ownerID);
			a.addressCount = a.addressCount.add(uint32(_addr.length));
		} else {
			_authorityCheck(investorData[_id].country);
		}
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
	function restrictAddresses(bytes32 _id, address[] _addr) external returns (bool) {

		if (!_checkMultiSig()) return false;
		if (authorityData[_id].addressCount > 0) {
			/* Only the owner can unregister addresses for an authority. */
			require(idMap[msg.sender].id == ownerID);
			Authority storage a = authorityData[_id];
			a.addressCount = a.addressCount.sub(uint32(_addr.length));
			require(a.addressCount >= a.multiSigThreshold);
			require(a.addressCount > 0);
		} else {
			_authorityCheck(investorData[_id].country);
		}
		for (uint256 i = 0; i < _addr.length; i++) {
			require(idMap[_addr[i]].id == _id);
			require(!idMap[_addr[i]].restricted);
			idMap[_addr[i]].restricted = true;
		}
		emit RestrictedAddresses(_id, _addr, idMap[msg.sender].id);
		return true;
	}

	/**
		@notice Fetch investor information using an address
		@dev
			This call increases gas efficiency around token transfers
			by minimizing the amount of calls to the registrar
		@param _addr Address to query
		@return bytes32 investor ID
		@return bool investor permission from isPermitted()
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
		require(i.country != 0, "Address not registered");
		return (_id, isPermitted(_addr), i.rating, i.country);
	}

	/**
		@notice Use addresses to fetch information on 2 investors
		@dev
			This call is increases gas efficiency around token transfers
			by minimizing the amount of calls to the registrar.
		@param _from first address to query
		@param _to second address to query
		@return bytes32 array of investor ID
		@return bool array - Investor permission from isPermitted()
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
		require(f.country != 0, "Sender not Registered");
		Investor storage t = investorData[idMap[_to].id];
		require(t.country != 0, "Receiver not Registered");
		return (
			bytes32[2]([idMap[_from].id, idMap[_to].id]),
			bool[2]([isPermitted(_from), isPermitted(_to)]),
			uint8[2]([f.rating,t.rating]),
			uint16[2]([f.country, t.country])
		);
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
		require (investorData[_id].country != 0);
		return investorData[_id].rating;
	}

	/**
		@notice Fetch investor region from an ID
		@param _id Investor ID
		@return bytes3 region code
	 */
	function getRegion(bytes32 _id) external view returns (bytes3) {
		require (investorData[_id].country != 0);
		return investorData[_id].region;
	}

	/**
		@notice Fetch investor country from an ID
		@param _id Investor ID
		@return string
	 */
	function getCountry(bytes32 _id) external view returns (uint16) {
		require (investorData[_id].country != 0);
		return investorData[_id].country;
	}

	/**
		@notice Fetch investor KYC expiration from an ID
		@param _id Investor ID
		@return uint40 expiration epoch time
	 */
	function getExpires(bytes32 _id) external view returns (uint40) {
		require (investorData[_id].country != 0);
		return investorData[_id].expires;
	}

	/**
		@notice Check if an an investor and address are permitted
		@param _addr Address to query
		@return bool permission
	 */
	function isPermitted(address _addr) public view returns (bool) {
		if (idMap[_addr].restricted) return false;
		Investor storage i = investorData[idMap[_addr].id];
		if (i.restricted) return false;
		if (i.expires < now) return false;
		if (authorityData[i.authority].restricted) return false;
		return true;
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

}
