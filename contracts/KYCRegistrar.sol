pragma solidity ^0.4.24;

import "./open-zeppelin/SafeMath.sol";


/// @title KYC Registrar
contract KYCRegistrar {

	using SafeMath for uint256;

	address owner;

	/*
		Investor accreditation levels:
			1 - unaccredited
			2 - accredited
			3 - qualified
	*/
	struct Investor {
		uint16 region;
		uint8 rating;
		uint40 expires;
	}

	/*
		Entity classes:
			1 - investor
			2 - issuer
			3 - exchange
	*/
	struct Entity {
		uint8 class;
		bool restricted;
		uint16 country;
	}

	struct Address {
		bytes32 id;
		bool restricted;

	}

	mapping (bytes32 => Entity) registry;
	mapping (address => Address) idMap;
	mapping (bytes32 => Investor) investorData;

	event NewInvestor(
		bytes32 id,
		uint16 country,
		uint16 region,
		uint8 rating,
		uint40 expires
	);
	event UpdatedInvestor(
		bytes32 id,
		uint16 region,
		uint8 rating,
		uint40 expires
	);
	event NewIssuer(bytes32 id, uint16 country);
	event NewExchange(bytes32 id, uint16 country);
	event EntityRestriction(bytes32 id, uint8 class, bool restricted);
	event NewRegisteredAddress(bytes32 id, uint8 class, address addr);
	event UnregisteredAddress(bytes32 id, uint8 class, address addr);

	modifier onlyOwner () {
		require (msg.sender == owner);
		_;
	}

	/// @notice KYC registrar constructor
	constructor () public {
		owner = msg.sender;
	}

	/// @notice Add investor to this registrar
	/// @param _id A hash of (_fullName, _ddmmyyyy, _taxID)
	/// @param _country Investor's country
	/// @param _region Specific region in investor's country
	/// @param _rating Unaccredited, accredited, qualified
	/// @param _expires Registry expiration, epoch time
	function addInvestor(
		bytes32 _id,
		uint16 _country,
		uint16 _region,
		uint8 _rating,
		uint40 _expires
	 )
		public
		onlyOwner
	{
		require (_rating > 0);
		_addEntity(_id, 1, _country);
		investorData[_id].region = _region;
		investorData[_id].rating = _rating;
		investorData[_id].expires = _expires;
		emit NewInvestor(_id, _country, _region, _rating, _expires);
	}

	/// @notice Add a new issuer to this registrar
	/// @param _id Issuer ID
	/// @param _country Issuer's country
	function addIssuer(bytes32 _id, uint16 _country) public onlyOwner {
		_addEntity(_id, 2, _country);
		emit NewIssuer(_id, _country);
	}

	/// @notice Add a new exchange to this registrar
	/// @param _id Exchange ID
	/// @param _country Exchange's country
	function addExchange(bytes32 _id, uint16 _country) public onlyOwner {
		_addEntity(_id, 3, _country);
		emit NewExchange(_id, _country);
	}

	/// @notice Add a new entity to this registrar
	/// @param _id Entity ID
	/// @param _class Entity's class
	/// @param _country Entity's country
	function _addEntity(bytes32 _id, uint8 _class, uint16 _country) internal {
		Entity storage e = registry[_id];
		require (e.class == 0);
		e.class = _class;
		e.country = _country;
	}

	/// @notice Update an investor
	/// @param _id Investor ID
	/// @param _region Investor's region
	/// @param _class Investor's rating
	/// @param _expires Registry expiration
	function updateInvestor(
		bytes32 _id,
		uint16 _region,
		uint8 _rating,
		uint40 _expires
	)
		public
		onlyOwner
	{
		require (registry[_id].class == 1);
		investorData[_id].region = _region;
		investorData[_id].rating = _rating;
		investorData[_id].expires = _expires;
		emit UpdatedInvestor(_id, _region, _rating, _expires);
	}

	/// @notice Set or remove an investor, issuer, or exchange's restricted status
	/// @dev Investors are restricted at the investor level, not address
	/// @param _id Entity's ID
	/// @param _restricted boolean
	function setRestricted(bytes32 _id, bool _restricted)    public onlyOwner {
		require (registry[_id].class != 0);
		registry[_id].restricted = _restricted;
		emit EntityRestriction(_id, registry[_id].class, _restricted);
	}

	/// @notice Register an address to an investor, issuer, or exchange
	/// @param _addr Entity's address
	/// @param _id Entity's ID
	function registerAddress(address _addr, bytes32 _id) public onlyOwner {
		require (idMap[_addr].id == 0);
		require (registry[_id].class != 0);
		idMap[_addr].id = _id;
		emit NewRegisteredAddress(_id, registry[_id].class, _addr);
	}

	/// @notice Flags an address as restricted instead of removing it
	/// @param _addr Entity's address
	/// @param _id Entity's ID
	function unregisterAddress(address _addr) public onlyOwner {
		require (idMap[_addr].id != 0);
		idMap[_addr].restricted = true;
		emit UnregisteredAddress(
			idMap[_addr].id,
			registry[idMap[_addr].id].class,
			_addr
		);
	}

	/// @notice Generate a unique investor ID
	/// @dev Hash returned == sha256(abi.encodePacked(_fullName, _ddmmyyyy, _taxID));
	/// @param _fullName Investor's full name
	/// @param _ddmmyyyy Investor's birth date
	/// @param _taxID Investor's tax ID
	/// @return string
	function generateInvestorID(
		string _fullName,
		uint256 _ddmmyyyy,
		string _taxID
	)
		public
		pure
		returns (bytes32)
	{
		return sha256(abi.encodePacked(_fullName, _ddmmyyyy, _taxID));
	}

	/// @notice Checks entity's restricted flag
	/// @param _id Entity's ID
	/// @return boolean
	function isPermitted(bytes32 _id) public view returns (bool) {
		require (registry[_id].class != 0);
		require (!registry[_id].restricted);
		return true;
	}

	/// @notice Checks address' restricted flag
	/// @param _addr Address to query
	/// @return boolean
	function isPermittedAddress(address _addr) public view returns (bool) {
		isPermitted(idMap[_addr].id);
		require (!idMap[_addr].restricted);
		return true;
	}

	/// @notice Checks restricted flag for three entities in one call
	/// @param _addr Address to query
	/// @return boolean
	function arePermitted(
		bytes32 _issuer,
		bytes32 _from,
		bytes32 _to
	)
		external
		view
		returns (bool)
	{
		isPermitted(_issuer);
		isPermitted(_from);
		isPermitted(_to);
		return true;
	}

	/// @notice Fetch rating of an entity
	/// @param _id Entity's ID
	/// @return integer
	function getRating(bytes32 _id) public view returns (uint8) {
		Investor storage i = investorData[_id];
		require (i.expires >= now);
		require (i.rating > 0);
		return investorData[_id].rating;
	}

	/// @notice Fetch ID from an address
	/// @param _addr Address to query
	/// @return string
	function getId(address _addr) public view returns (bytes32) {
		return idMap[_addr].id;
	}

	/// @notice Fetch class from an entity
	/// @param _id Entity's ID
	/// @return integer
	function getClass(bytes32 _id) public view returns (uint8) {
		/*
			Entity classes:
				1 - investor
				2 - issuer
				3 - exchange
		*/
		return registry[_id].class;
	}

	/// @notice Fetch country from an entity
	/// @param _id Entity's ID
	/// @return string
	function getCountry(bytes32 _id) public view returns (uint16) {
		return registry[_id].country;
	}

	/// @notice Fetch region from an entity
	/// @param _id Entity's ID
	/// @return string
	function getRegion(bytes32 _id) public view returns (uint16) {
		return investorData[_id].region;
	}

	/// @notice Fetch entity from an address
	/// @param _addr Address to query
	/// @return Array of (id, class, country)
	function getEntity(
		address _addr
	)
		public
		view
		returns (
			bytes32 _id,
			uint8 _class,
			uint16 _country
		)
	{
		_id = idMap[_addr].id;
		return (
			_id,
			registry[_id].class,
			registry[_id].country
		);
	}

	/// @notice Fetch investor from an ID
	/// @param _id Investor's ID
	/// @return Array of (country, region, rating, expires)
	function getInvestor(
		bytes32 _id
	)
		public
		view
		returns (
			uint16 _country,
			uint16 _region,
			uint8 _rating,
			uint40 _expires
		)
	{
		require (registry[_id].class == 1);
		return (
			registry[_id].country,
			investorData[_id].region,
			investorData[_id].rating,
			investorData[_id].expires
		);
	}

}
