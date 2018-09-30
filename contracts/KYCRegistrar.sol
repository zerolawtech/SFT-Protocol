pragma solidity ^0.4.24;

import "./open-zeppelin/SafeMath.sol";
import "./interfaces/Factory.sol";

/// @title KYC Registrar
contract KYCRegistrar {

	using SafeMath for uint256;

	bytes32 ownerID;

	IssuerFactoryInterface issuerFactory;
	TokenFactoryInterface tokenFactory;

	struct Address {
		bytes32 id;
		bool restricted;
	}

	/*
		Entity classes:
			1 - investor
			2 - issuer
			3 - exchange
			255 - authority
	*/
	struct Entity {
		uint8 class;
		uint16 country;
		bool restricted;
	}

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

	struct Issuer {
		address issuerContract;
		mapping (address => bool) allowed;
	}

	struct Authority {
		mapping (uint16 => bool) countries;
		mapping (bytes32 => address[]) multiSigAuth;
		uint8 multiSigThreshold;
		uint8 addressCount;
	}

	mapping (address => Address) idMap;
	mapping (bytes32 => Entity) entityData;
	mapping (bytes32 => Investor) investorData;
	mapping (bytes32 => Issuer) issuerData;
	mapping (bytes32 => Authority) authorityData;
	mapping (string => address) tickerRegistry;

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
	event NewIssuer(
		bytes32 id,
		uint16 country,
		address issuerContract,
		bytes32 authority
	);
	event NewExchange(bytes32 id, uint16 country, bytes32 authority);
	event NewAuthority(bytes32 id);
	event NewIssuerFactory(address factory);
	event NewTokenFactory(address factory);
	event EntityRestriction(
		bytes32 id,
		uint8 class,
		bool restricted,
		bytes32 authority
	);
	event NewRegisteredAddress(
		bytes32 id,
		uint8 class,
		address addr,
		bytes32 authority
	);
	event UnregisteredAddress(
		bytes32 id,
		uint8 class,
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
		_authorityCheck(idMap[msg.sender].id, entityData[_id].country);	
		_;
	}

	function _authorityCheck(bytes32 _id, uint16 _country) internal view {
		require (_country != 0);
		require (entityData[_id].class == 255);
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
		_addEntity(ownerID, 255, 0);
		Authority storage a = authorityData[ownerID];
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
		if (!_checkMultiSig()) return false;
		_addEntity(_id, 1, _country);
		investorData[_id].region = _region;
		investorData[_id].rating = _rating;
		investorData[_id].expires = _expires;
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

	/// @notice Add a new issuer to this registrar
	/// @param _id Issuer ID
	/// @param _country Issuer's country
	/// @param _addr Array of addressses to register as issuer
	/// @return bool
	function addIssuer(
		bytes32 _id, 
		uint16 _country,
		address[] _addr
	)
		external
		onlyAuthority(_country)
		returns (bool)
	{
		if (!_checkMultiSig()) return false;
		_addEntity(_id, 2, _country);
		issuerData[_id].issuerContract = issuerFactory.newIssuer(_id);
		emit NewIssuer(
			_id,
			_country,
			issuerData[_id].issuerContract,
			idMap[msg.sender].id
		);
		_addAddresses(_id, _addr);
		return true;
	}

	/// @notice Add a new exchange to this registrar
	/// @param _id Exchange ID
	/// @param _country Exchange's country
	/// @param _addr Array of addressses to register as exchange
	/// @return bool
	function addExchange(
		bytes32 _id,
		uint16 _country,
		address[] _addr
	)
		external
		onlyAuthority(_country)
		returns (bool)
	{
		if (!_checkMultiSig()) return false;
		_addEntity(_id, 3, _country);
		emit NewExchange(_id, _country, idMap[msg.sender].id);
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
		require (_addr.length >= _threshold);
		if (!_checkMultiSig()) return false;
		_addEntity(_id, 255, 0);
		authorityData[_id].addressCount = uint8(_addr.length);
		authorityData[_id].multiSigThreshold = _threshold;
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
		require (entityData[_id].class == 255);
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
		require (entityData[_id].class == 255);
		Authority storage a = authorityData[_id];
		for (uint256 i = 0; i < _countries.length; i++) {
			a.countries[_countries[i]] = _auth;
		}
		return true;
	}

	function _checkMultiSig() internal returns (bool) {
		bytes32 _id = idMap[msg.sender].id;
		require (entityData[_id].class == 255);
		Authority storage a = authorityData[_id];
		bytes32 _callHash = keccak256(msg.data);
		if (a.multiSigAuth[_callHash].length.add(1) >= a.multiSigThreshold) {
			delete a.multiSigAuth[_callHash];
			return true;
		}
		for (uint256 i = 0; i < a.multiSigAuth[_callHash].length; i++) {
			if (a.multiSigAuth[_callHash][i] == msg.sender) {
				return false;
			}
		}
		a.multiSigAuth[_callHash].push(msg.sender);
		return false;
	}



	/// @notice Add a new entity to this registrar
	/// @param _id Entity ID
	/// @param _class Entity's class
	/// @param _country Entity's country
	function _addEntity(bytes32 _id, uint8 _class, uint16 _country) internal {
		require (_country > 0);
		require (_id != 0);
		Entity storage e = entityData[_id];
		require (e.class == 0);
		e.class = _class;
		e.country = _country;
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
		require (entityData[_id].class == 1);
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
		/*
			Only the owner can modify the restricted status of an authority.
		*/
		if (entityData[_id].class == 255) {
			require (idMap[msg.sender].id == ownerID);
			require (_id != ownerID);
		}
		require (entityData[_id].class != 0);
		if (!_checkMultiSig()) return false;
		entityData[_id].restricted = _restricted;
		emit EntityRestriction(
			_id,
			entityData[_id].class,
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
		if (entityData[_id].class == 255) {
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
			entityData[idMap[_addr].id].country
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
			entityData[idMap[_addr].id].class,
			_addr,
			idMap[msg.sender].id
		);
		return true;
	}

	function _addAddresses(bytes32 _id, address[] _addr) internal {
		require (entityData[_id].class != 0);
		for (uint256 i = 0; i < _addr.length; i++) {
			require (idMap[_addr[i]].id == 0);
			idMap[_addr[i]].id = _id;
			emit NewRegisteredAddress(
				_id,
				entityData[_id].class,
				_addr[i],
				idMap[msg.sender].id
			);
		}
	}

	function setIssuerFactory(address _factory) external onlyOwner returns (bool) {
		if (!_checkMultiSig()) return false;
		issuerFactory = IssuerFactoryInterface(_factory);
		emit NewIssuerFactory(_factory);
		return true;
	}

	function setTokenFactory(address _factory) external onlyOwner returns (bool) {
		if (!_checkMultiSig()) return false;
		tokenFactory = TokenFactoryInterface(_factory);
		emit NewTokenFactory(_factory);
		return true;
	}

	function issueNewToken(
		bytes32 _id,
		string _name,
		string _symbol,
		uint256 _totalSupply
	)
		external
		returns (address)
	{
		require (msg.sender == issuerData[_id].issuerContract);
		require (!entityData[_id].restricted);
		require (tickerRegistry[_symbol] == 0);
		address _token = tokenFactory.newToken(msg.sender, _name, _symbol, _totalSupply);
		issuerData[_id].allowed[_token] = true;
		tickerRegistry[_symbol] = _token;
		return _token;
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
		external
		pure
		returns (bytes32)
	{
		return sha256(abi.encodePacked(_fullName, _ddmmyyyy, _taxID));
	}

	/// @notice Check that an address is associated to an ID and not restricted
	/// @dev Used for modifier onlyIssuer
	/// @param _id ID that should be associated with address
	/// @param _addr address to check against ID
	/// @return bool
	function isPermittedIssuer(bytes32 _id, address _addr) external view returns (bool) {
		require (idMap[_addr].id == _id);
		require (!idMap[_addr].restricted);
		require (!entityData[_id].restricted);
		return true;
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

	/// @notice Fetch ID from an address
	/// @param _addr Address to query
	/// @return string
	function getId(address _addr) external view returns (bytes32) {
		return idMap[_addr].id;
	}

	/// @notice Fetch class from an entity
	/// @param _id Entity's ID
	/// @return integer
	function getClass(bytes32 _id) external view returns (uint8) {
		return entityData[_id].class;
	}

	/// @notice Fetch country from an entity
	/// @param _id Entity's ID
	/// @return string
	function getCountry(bytes32 _id) external view returns (uint16) {
		return entityData[_id].country;
	}

	/// @notice Fetch region from an entity
	/// @param _id Entity's ID
	/// @return string
	function getRegion(bytes32 _id) external view returns (uint16) {
		return investorData[_id].region;
	}

	/// @notice Fetch entity from an address
	/// @param _addr Address to query
	/// @return Array of (id, class, country)
	function getEntity(
		address _addr
	)
		external
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
			entityData[_id].class,
			entityData[_id].country
		);
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
		require (entityData[_id].class == 1);
		return (
			entityData[_id].country,
			investorData[_id].region,
			investorData[_id].rating,
			investorData[_id].expires
		);
	}

	/// @notice Check registrar level permissions around a token transfer
	/// @param _issuer ID of the issuer that created the token
	/// @param _token address of the token contract
	/// @param _auth address of the caller attempting the transfer (authority)
	/// @param _from address that the tokens are to be sent from
	/// @param _to address that the tokens are to be sent to
	/// @return ID of caller, arrays of ID, class, country of sender/recipient
	function checkTransfer(
		bytes32 _issuer,
		address _token,
		address _auth,
		address _from,
		address _to
	)
		external
		view
		returns (
			bytes32,
			bytes32[2],
			uint8[2],
			uint16[2]
		)
	{
		/*
			If the issuer, token, authority, or receiver are restricted
			the transfer is blocked.
		*/
		require (!entityData[_issuer].restricted);
		require (issuerData[_issuer].allowed[_token]);
		require (!idMap[_auth].restricted);
		_checkAddress(_issuer, _to);
		bytes32 _authId = idMap[_auth].id;
		/*
			If the authority is the issuer, check that the calling addresss
			is not restricted.
		*/
		if (_authId == _issuer) {
			require (!idMap[_auth].restricted);
		}
		/*
			If the authority is the issuer's IssuingEntity contract, the call
			is being sent by a module. Set the authority to be the issuer.
		*/
		else if (issuerData[_issuer].issuerContract == _auth) {
			_authId = _issuer;
		/* In all other cases, check that the sender is not restricted. */
		} else {
			_checkAddress(_issuer, _from);
		}
		bytes32 _fromId = idMap[_from].id;
		bytes32 _toId = idMap[_to].id;
		/*
			Data about the involved entities is returned to prevent repetetive
			calls to the registrar contract during the token transfer.
		*/
		return (
			_authId,
			bytes32[2]([_fromId, _toId]),
			uint8[2]([entityData[_fromId].class, entityData[_toId].class]),
			uint16[2]([entityData[_fromId].country, entityData[_toId].country])
		);
	}

	function _checkAddress(bytes32 _issuer, address _addr) internal view {
		bytes32 _id = idMap[_addr].id;
		require (entityData[_id].class != 0);
		require (entityData[_id].class != 255);
		/* Issuers can only hold their own tokens. */
		if (entityData[_id].class == 2) {
			require (_id == _issuer);
		}
		require (!entityData[_id].restricted);
		require (!idMap[_addr].restricted);
	}

}
