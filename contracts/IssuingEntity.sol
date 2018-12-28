pragma solidity >=0.4.24 <0.5.0;

import "./open-zeppelin/SafeMath.sol";
import "./KYCRegistrar.sol";
import "./SecurityToken.sol";
import "./Custodian.sol";
import "./components/Modular.sol";
import "./components/MultiSig.sol";

/** @title Issuing Entity */
contract IssuingEntity is Modular, MultiSig {

	using SafeMath32 for uint32;
	using SafeMath for uint256;

	/*
		Each country can have specific limits for each investor class.
		minRating corresponds to the minimum investor level for this country.
		counts[0] and levels[0] == the sum total of counts[1:] and limits[1:]
	*/
	struct Country {
		uint32[8] counts;
		uint32[8] limits;
		bool allowed;
		uint8 minRating;
	}

	struct Account {
		uint32 count;
		uint8 rating;
		uint8 regKey;
		bool restricted;
		mapping (bytes32 => bool) custodians;
	}

	struct Token {
		bool set;
		bool restricted;
	}

	struct RegistrarContract {
		KYCRegistrar addr;
		bool restricted;
	}

	struct CustodianContract {
		address addr;
		bool restricted;
	}

	bool locked;
	bool mutex;
	RegistrarContract[] registrars;
	uint32[8] counts;
	uint32[8] limits;
	mapping (uint16 => Country) countries;
	mapping (bytes32 => Account) accounts;
	mapping (bytes32 => CustodianContract) custodians;
	mapping (address => Token) tokens;
	mapping (string => bytes32) documentHashes;

	event TransferOwnership(
		address indexed token,
		bytes32 indexed from,
		bytes32 indexed to,
		uint256 value
	);
	event BeneficialOwnerSet(
		address indexed custodian,
		bytes32 indexed id,
		bool owned
	);
	event CountryModified(
		uint16 indexed country,
		bool allowed,
		uint8 minrating,
		uint32[8] limits
	);
	event InvestorLimitSet(uint16 indexed country, uint32[8] limits);
	event NewDocumentHash(string indexed document, bytes32 documentHash);
	event RegistrarSet(address indexed registrar, bool allowed);
	event CustodianAdded(address indexed custodian);
	event TokenAdded(address indexed token);
	event InvestorRestriction(bytes32 indexed id, bool allowed);
	event TokenRestriction(address indexed token, bool allowed);
	event GlobalRestriction(bool allowed);
	
	/** @dev check that call originates from a registered, unrestricted token */
	modifier onlyToken() {
		require(tokens[msg.sender].set && !tokens[msg.sender].restricted);
		_;
	}

	/**
		@notice Issuing entity constructor
		@param _owners Array of addresses to associate with owner
		@param _threshold multisig threshold for owning authority
	 */
	constructor(
		address[] _owners,
		uint32 _threshold
	)
		MultiSig(_owners, _threshold)
		public 
	{
		/* First registrar is empty so Account.regKey == 0 means it is unset. */
		registrars.push(RegistrarContract(KYCRegistrar(0), false));
	}

	/**
		@notice Fetch total investor counts and limits
		@return counts, limits
	 */
	function getInvestorCounts() external view returns (uint32[8], uint32[8]) {
		return (counts, limits);
	}

	/**
		@notice Fetch minrating, investor counts and limits of a country
		@dev counts[0] and levels[0] == the sum of counts[1:] and limits[1:]
		@param _country Country to query
		@return uint32 minRating, uint32 arrays of counts, limits
	 */
	function getCountry(
		uint16 _country
	)
		external
		view
		returns (uint32 _minRating, uint32[8] _count, uint32[8] _limit)
	{
		return (
			countries[_country].minRating,
			countries[_country].counts,
			countries[_country].limits
		);
	}

	/**
		@notice Set all information about a country
		@param _country Country to modify
		@param _allowed Is country approved
		@param _minRating minimum investor rating
		@param _limits array of investor limits
		@return bool success
	 */
	function setCountry(
		uint16 _country,
		bool _allowed,
		uint8 _minRating,
		uint32[8] _limits
	)
		external
		returns (bool)
	{
		if (!_checkMultiSig()) return false;
		Country storage c = countries[_country];
		c.limits = _limits;
		c.minRating = _minRating;
		c.allowed = _allowed;
		emit CountryModified(_country, _allowed, _minRating, _limits);
		return true;
	}

	/**
		@notice Initialize many countries in a single call
		@dev
			This call is useful if you have a lot of countries to approve
			where there is no investor limit specific to the investor ratings
		@param _country Array of counties to add
		@param _minRating Array of minimum investor ratings necessary for each country
		@param _limit Array of maximum mumber of investors allowed from this country
		@return bool success
	 */
	function setCountries(
		uint16[] _country,
		uint8[] _minRating,
		uint32[] _limit
	)
		external
		returns (bool)
	{
		require(_country.length == _minRating.length);
		require(_country.length == _limit.length);
		if (!_checkMultiSig()) return false;
		for (uint256 i = 0; i < _country.length; i++) {
			require(_minRating[i] != 0);
			Country storage c = countries[_country[i]];
			c.allowed = true;
			c.minRating = _minRating[i];
			c.limits[0] = _limit[i];
			emit CountryModified(_country[i], true, _minRating[i], c.limits);

		}
	}

	/**
		@notice Set investor limits
		@dev
			_limits[0] is the total investor limit, [1:] correspond to limits
			at each specific investor rating. Setting a value of 0 means there
			is no limit.
		@param _limits Array of limits
		@return bool success
	 */
	function setInvestorLimits(
		uint32[8] _limits
	)
		external
		returns (bool)
	{
		if (!_checkMultiSig()) return false;
		limits = _limits;
		emit InvestorLimitSet(0, _limits);
		return true;
	}

	/**
		@notice Check if transfer is possible based on issuer level restrictions
		@param _token address of token being transferred
		@param _auth address of the caller attempting the transfer
		@param _from address of the sender
		@param _to address of the receiver
		@return bytes32 ID of caller
		@return bytes32[] IDs of sender and receiver
		@return uint8[] ratings of sender and receiver
		@return uint16[] countries of sender and receiver
	 */
	function checkTransfer(
		address _token,
		address _auth,
		address _from,
		address _to,
		bool _zero,
		uint256 _value
	)
		external
		returns (
			bytes32 _authID,
			bytes32[2] _id,
			uint8[2] _rating,
			uint16[2] _country
		)
	{
		_authID = _getID(_auth, 0);
		_id[0] = _getID(_from, 0);
		_id[1] = _getID(_to, 0);
		
		if (_authID == ownerID && idMap[_auth].id != ownerID) {
			/* This enforces sub-authority permissioning around transfers */
			_checkAuth(
				_auth,
				_authID == _id[0] ? bytes4(0xa9059cbb) : bytes4(0x23b872dd)
			);
		}

		address _addr = (_authID == _id[0] ? _auth : _from);
		bool[2] memory _allowed;

		(_allowed, _rating, _country) = _getInvestors(
			[_addr, _to],
			_id,
			[accounts[idMap[_addr].id].regKey, accounts[_id[1]].regKey]
		);
		Account storage a = accounts[_id[0]];
		_checkTransfer(
			_token,
			_authID,
			_id,
			_allowed,
			_rating,
			_country,
			_zero ? a.count.sub(1) : a.count,
			_value
			);
		return (_authID, _id, _rating, _country);
	}	

	function _checkAuth(address _auth, bytes4 _sig) internal view {
		Authority storage a = authorityData[idMap[_auth].id];
		require(
			a.approvedUntil >= now &&	
			a.signatures[_sig], "Authority is not permitted"
		);
	}

	function checkTransferCustodian(
		address _cust,
		address _token,
		bytes32[2] _id,
		bool _stillOwner
	)
		external
		returns (
			bytes32 _custID,
			uint8[2] _rating,
			uint16[2] _country
		)
	{
		require(
			custodians[idMap[_cust].id].addr == _cust,
			"Custodian not registered"
		);
		require(custodians[_id[1]].addr == 0, "Receiver is custodian");
		_getID(0, _id[0]);
		_getID(0, _id[1]);
		bool[2] memory _allowed;
		(
			_allowed,
			_rating,
			_country
		) = _getInvestors(
			[address(0), address(0)],
			_id,
			[accounts[_id[0]].regKey, accounts[_id[1]].regKey]
		);
		_setRating(_id[0], _rating[0], _country[0]);
		_setRating(_id[1], _rating[1], _country[1]);
		if (accounts[_id[0]].count > 0 && !_stillOwner) {
			uint32 _count = accounts[_id[0]].count.sub(1);
		} else {
			_count = accounts[_id[0]].count;
		}
		_checkTransfer(
			_token,
			idMap[_cust].id,
			_id,
			_allowed,
			_rating,
			_country,
			_count,
			0)
		;
		return (idMap[_cust].id, _rating, _country);
	}

	/**
		@notice internal check if transfer is permitted
		@param _token address of token being transferred
		@param _authID id hash of caller
		@param _id addresses of sender and receiver
		@param _allowed array of permission bools from registrar
		@param _rating array of investor ratings
		@param _country array of investor countries
	 */
	function _checkTransfer(
		address _token,
		bytes32 _authID,
		bytes32[2] _id,
		bool[2] _allowed,
		uint8[2] _rating,
		uint16[2] _country,
		uint32 _tokenCount,
		uint256 _value
	)
		internal
	{	
		require(tokens[_token].set);
		/* If issuer is not the authority, check the sender is not restricted */
		if (_authID != ownerID) {
			require(!locked, "Transfers locked: Issuer");
			require(!tokens[_token].restricted, "Transfers locked: Token");
			require(!accounts[_id[0]].restricted, "Sender restricted: Issuer");
			require(_allowed[0], "Sender restricted: Registrar");	
		}
		/* Always check the receiver is not restricted. */
		require(!accounts[_id[1]].restricted, "Receiver restricted: Issuer");
		require(_allowed[1], "Receiver restricted: Registrar");
		if (_id[0] != _id[1]) {
			/*
				A rating of 0 implies the receiver is the issuer or a
				custodian, no further checks are needed.
			*/
			if (_rating[1] != 0) {
				Country storage c = countries[_country[1]];
				require(c.allowed, "Reciever blocked: Country");
				require(_rating[1] >= c.minRating, "Receiver blocked: Rating");
				/*  
					If the receiving investor currently has 0 balance and no
					custodians, make sure a slot is available for allocation.
				*/ 
				if (accounts[_id[1]].count == 0) {
					/* create a bool to prevent repeated comparisons */
					bool _check = (_rating[0] == 0 || _tokenCount > 0);
					/*
						If the sender is an investor and still retains a balance,
						a new slot must be available.
					*/
					if (_check) {
						require(
							limits[0] == 0 ||
							counts[0] < limits[0],
							"Total Investor Limit"
						);
					}
					/*
						If the investors are from different countries, make sure
						a slot is available in the overall country limit.
					*/
					if (_check || _country[0] != _country[1]) {
						require(
							c.limits[0] == 0 ||
							c.counts[0] < c.limits[0],
							"Country Investor Limit"
						);
					}
					if (!_check) {
						_check = _rating[0] != _rating[1];
					}
					/*
						If the investors are of different ratings, make sure a
						slot is available in the receiver's rating in the overall
						count.
					*/
					if (_check) {
						require(
							limits[_rating[1]] == 0 ||
							counts[_rating[1]] < limits[_rating[1]],
							"Total Investor Limit: Rating"
						);
					}
					/*
						If the investors don't match in country or rating, make
						sure a slot is available in both the specific country
						and rating for the receiver.
					*/
					if (_check || _country[0] != _country[1]) {
						require(
							c.limits[_rating[1]] == 0 ||
							c.counts[_rating[1]] < c.limits[_rating[1]],
							"Country Investor Limit: Rating"
						);
					}
				}
			}
		}
		/* bytes4 signature for issuer module checkTransfer() */
		_callModules(
			0x47fca5df,
			abi.encode(_token, _authID, _id, _rating, _country, _value)
		);
	}

	/**
		@notice External view to fetch an investor ID from an address
		@param _addr address of token being transferred
		@return bytes32 investor ID
	 */
	function getID(address _addr) external view returns (bytes32) {
		(bytes32 _id, uint8 _key) = _getIDView(_addr, 0);
		return _id;
	}

	/**
		@notice internal investor ID fetch, updates local record
		@param _addr address of token being transferred
		@return bytes32 investor ID
	 */
	function _getID(address _addr, bytes32 _id) internal returns (bytes32) {
		uint8 _key;
		(_id, _key) = _getIDView(_addr, _id);
		if (_addr != 0 && idMap[_addr].id == 0) {
			idMap[_addr].id = _id;
		}
		if (accounts[_id].regKey != _key) {
			accounts[_id].regKey = _key;
		}
		return _id;
	}

	/**
		@notice internal investor ID fetch
		@dev common logic for getID() and _getID()
		@param _addr address of token being transferred
		@return bytes32 investor ID, uint8 registrar index
	 */
	function _getIDView(
		address _addr,
		bytes32 _id
	)
		internal
		view
		returns (bytes32, uint8)
	{
		if (_id == 0) {
			_id = idMap[_addr].id;
		}
		if (
			authorityData[_id].addressCount > 0 ||
			_addr == address(this)
		) {
			return (ownerID, 0);
		}
		if (_id == 0) {
			for (uint256 i = 1; i < registrars.length; i++) {
				if (!registrars[i].restricted) {
					_id = registrars[i].addr.getID(_addr);
					if (_id != 0) {
						return (_id, uint8(i));
					}
				}
			}
			revert("Address not registered");
		}
		if (custodians[_id].addr != 0) {
			return (_id, 0);
		}
		if (
			accounts[_id].regKey == 0 ||
			registrars[accounts[_id].regKey].restricted
		) {
			for (i = 1; i < registrars.length; i++) {
				if (registrars[i].restricted) continue;
				if (
					(_addr != 0 && _id == registrars[i].addr.getID(_addr)) ||
					(_addr == 0 && registrars[i].addr.isRegistered(_id))
				) {
					return (_id, uint8(i));
				}
			}
			if (registrars[accounts[_id].regKey].restricted) {
				revert("Registrar restricted");
			}
			revert("Address not registered");
		}
		return (_id, accounts[_id].regKey);
	}

	/**
		@dev fetch investor data from registrar(s)
		@param _addr array of investor addresses
		@param _key array of registrar indexes
		@return permissions, ratings, and countries of investors
	 */
	function _getInvestors(
		address[2] _addr,
		bytes32[2] _id,
		uint8[2] _key
	)
		internal
		view
		returns (
			bool[2] _allowed,
			uint8[2] _rating,
			uint16[2] _country
		)
	{
		/* If key == 0 the address belongs to the issuer or a custodian. */
		if (_key[0] == 0) {
			_allowed[0] = true;
			_rating[0] = 0;
			_country[0] = 0;
		}
		if (_key[1] == 0) {
			_allowed[1] = true;
			_rating[1] = 0;
			_country[1] = 0;
		}
		/* If both investors are in the same registry, call getInvestors */
		KYCRegistrar r = registrars[_key[0]].addr;
		if (_key[0] == _key[1] && _key[0] != 0) {
			if (_addr[0] != 0) {

				(
					_id,
					_allowed,
					_rating,
					_country
				) = r.getInvestors(_addr[0], _addr[1]);
			} else {
				(
					_allowed,
					_rating,
					_country
				) = r.getInvestorsByID(_id[0], _id[1]);
			}
		/* Otherwise, call getInvestor at each registry */
		} else if (_addr[0] != 0) {
			if (_key[0] != 0) {
				(
					_id[0],
					_allowed[0],
					_rating[0],
					_country[0]
				) = r.getInvestor(_addr[0]);
			}
			if (_key[1] != 0) {
				(
					_id[1],
					_allowed[1],
					_rating[1],
					_country[1]
				) = registrars[_key[1]].addr.getInvestor(_addr[1]);
			}	
		} else {
			if (_key[0] != 0) {
				(
					_allowed[0],
					_rating[0],
					_country[0]
				) = r.getInvestorByID(_id[0]);
			}
			if (_key[1] != 0) {
				(
					_allowed[1],
					_rating[1],
					_country[1]
				) = registrars[_key[1]].addr.getInvestorByID(_id[1]);
			}
		}
		return (_allowed, _rating, _country);
	}

	/**
		@notice Transfer tokens through the issuing entity level
		@param _id Array of sender/receiver IDs
		@param _rating Array of sender/receiver ratings
		@param _country Array of sender/receiver countries
		@param _value Number of tokens being transferred
		@return bool success
	 */
	function transferTokens(
		bytes32[2] _id,
		uint8[2] _rating,
		uint16[2] _country,
		uint256 _value,
		bool[2] _zero
	)
		external
		onlyToken
		returns (bool)
	{
		/* custodian re-entrancy guard */
		require (!mutex);
		Account storage _from = accounts[_id[0]];
		Account storage _to = accounts[_id[1]];
		if (_zero[0]) {
			_from.count = _from.count.sub(1);
		}
		if (_zero[1]) {
			_to.count = _to.count.add(1);
		}
		
		/* If no transfer of ownership, return true immediately */
		if (_id[0] == _id[1]) return true;
		/*
			If receiver is a custodian and sender is an investor, notify
			the custodian contract.
		*/
		if (custodians[_id[1]].addr != 0) {
			Custodian c = Custodian(custodians[_id[1]].addr);
			mutex = true;
			require(c.receiveTransfer(msg.sender, _id[0], _value));
			if (_rating[0] > 0 && !_from.custodians[_id[1]]) {
				_from.count = _from.count.add(1);
				_from.custodians[_id[1]] = true;
				emit BeneficialOwnerSet(address(c), _id[0], true);
			}
			mutex = false;
		} else if (custodians[_id[0]].addr == 0) {
			emit TransferOwnership(msg.sender, _id[0], _id[1], _value);
		}
		
		if (_rating[0] != 0) {
			_setRating(_id[0], _rating[0], _country[0]);
			/* If investor account balance was 0, increase investor counts */
			if (_from.count == 0) {
				_decrementCount(_rating[0], _country[0]);
			}
		}
		if (_rating[1] != 0) {
			_setRating(_id[1], _rating[1], _country[1]);
			/* If investor account balance was 0, increase investor counts */
			if (_to.count == 1) {
				_incrementCount(_rating[1], _country[1]);
			}
		}
		/* bytes4 signature for issuer module transferTokens() */
		_callModules(
			0x0cfb54c9,
			abi.encode(msg.sender, _id, _rating, _country, _value)
		);
		
		return true;
	}

	function transferCustodian(
		bytes32 _custID,
		bytes32[2] _id,
		uint8[2] _rating,
		uint16[2] _country,
		uint256 _value,
		bool _stillOwner
	)
		external
		onlyToken
		returns (bool)
	{

		_setBeneficialOwners(_custID, _id[0], _stillOwner);
		_setBeneficialOwners(_custID, _id[1], true);

		/* bytes4 signature for token module transferTokensCustodian() */
		_callModules(0x38a1b79a, abi.encode(
			msg.sender,
			custodians[_custID].addr,
			_id,
			_rating,
			_country,
			_value
		));
		return true;
	}

	/**
		@notice Affect a direct balance change (burn/mint) at the issuing entity level
		@dev This can only be called by a token
		@param _owner Token owner
		@param _old Old balance
		@param _new New balance
		@return id, rating, and country of the affected investor
	 */
	function modifyBalance(
		address _owner,
		uint256 _old,
		uint256 _new
	)
		external
		onlyToken
		returns (
			bytes32 _id,
			uint8 _rating,
			uint16 _country
		)
	{
		if (_owner == address(this)) {
			_id = ownerID;
			_rating = 0;
			_country = 0;
		} else {
			bool _allowed;
			uint8 _key = accounts[idMap[_owner].id].regKey;
			(
				_id,
				_allowed,
				_rating,
				_country
			) = registrars[_key].addr.getInvestor(_owner);
		}
		Account storage a = accounts[_id];
		if (_old == 0) {
			a.count = a.count.add(1);
			if (a.count == 1) {
				_incrementCount(_rating, _country);
			}
		} else if (_new == 0) {
			a.count = a.count.sub(1);
			if (a.count == 0) {
				_decrementCount(_rating, _country);
			}
		}
		
		/* bytes4 signature for token module balanceChanged() */
		_callModules(
			0x4268353d,
			abi.encode(msg.sender, _id, _rating, _country, _old, _new)
		);
		return (_id, _rating, _country);
	}

	function _setRating(bytes32 _id, uint8 _rating, uint16 _country) internal {
		Account storage a = accounts[_id];
		if (_rating == a.rating) return;
		/* if local rating is not 0, rating has changed */
		if (a.rating > 0) {
			uint32[8] storage c = countries[_country].counts;
			c[_rating] = c[_rating].sub(1);
			c[a.rating] = c[a.rating].add(1);
		}
		a.rating = _rating;
	}

	/**
		@notice Increment investor count
		@param _r Investor rating
		@param _c Investor country
		@return bool success
	 */
	function _incrementCount(uint8 _r, uint16 _c) internal {
		counts[0] = counts[0].add(1);
		counts[_r] = counts[_r].add(1);
		countries[_c].counts[0] = countries[_c].counts[0].add(1);
		countries[_c].counts[_r] = countries[_c].counts[_r].add(1);
	}

	/**
		@notice Decrement investor count
		@param _r Investor rating
		@param _c Investor country
		@return bool success
	 */
	function _decrementCount(uint8 _r, uint16 _c) internal {
		counts[0] = counts[0].sub(1);
		counts[_r] = counts[_r].sub(1);
		countries[_c].counts[0] = countries[_c].counts[0].sub(1);
		countries[_c].counts[_r] = countries[_c].counts[_r].sub(1);
	}

	/**
		@notice Set document hash
		@param _documentID Document ID being hashed
		@param _hash Hash of the document
		@return bool success
	 */
	function setDocumentHash(
		string _documentID,
		bytes32 _hash
	)
		external
		returns (bool)
	{
		if (!_checkMultiSig()) return false;
		require(documentHashes[_documentID] == 0);
		documentHashes[_documentID] = _hash;
		emit NewDocumentHash(_documentID, _hash);
		return true;
	}

	/**
		@notice Fetch document hash
		@param _documentID Document ID to fetch
		@return document hash
	 */
	function getDocumentHash(string _documentID) external view returns (bytes32) {
		return documentHashes[_documentID];
	}

	/**
		@notice Attach or remove a KYCRegistrar contract
		@param _registrar address of registrar
		@param _allowed registrar permission
		@return bool success
	 */
	function setRegistrar(
		KYCRegistrar _registrar,
		bool _allowed
	)
		external
		returns (bool)
	{
		if (!_checkMultiSig()) return false;
		for (uint256 i = 1; i < registrars.length; i++) {
			if (registrars[i].addr == _registrar) {
				registrars[i].restricted = !_allowed;
				emit RegistrarSet(_registrar, _allowed);
				return true;
			}
		}
		if (_allowed) {
			registrars.push(RegistrarContract(_registrar, false));
			emit RegistrarSet(_registrar, _allowed);
			return true;
		}
		revert();		
	}

	/**
		@notice Get address of the registrar an investor is associated with
		@param _id Investor ID
		@return registrar address
	 */
	function getInvestorRegistrar(bytes32 _id) external view returns (address) {
		return registrars[accounts[_id].regKey].addr;
	}

	/**
		@notice Add a custodian
		@dev
			Custodians are entities such as broker or exchanges that are approved
			to hold tokens for 1 or more beneficial owners.
			https://sft-protocol.readthedocs.io/en/latest/custodian.html
		@param _custodian address of custodian contract
		@return bool success
	 */
	function addCustodian(address _custodian) external returns (bool) {
		if (!_checkMultiSig()) return false;
		bytes32 _id = Custodian(_custodian).ownerID();
		idMap[_custodian].id = _id;
		custodians[_id].addr = _custodian;
		emit CustodianAdded(_custodian);
		return true;
	}

	/**
		@notice Add a new security token contract
		@param _token Token contract address
		@return bool success
	 */
	function addToken(address _token) external returns (bool) {
		if (!_checkMultiSig()) return false;
		SecurityToken token = SecurityToken(_token);
		require(!tokens[_token].set);
		require(token.ownerID() == ownerID);
		require(token.circulatingSupply() == 0);
		tokens[_token].set = true;
		emit TokenAdded(_token);
		return true;
	}

	/**
		@notice Set restriction on an investor ID
		@dev
			This is used for regular investors or custodians. Restrictions
			on sub-authorities must be handled with MultiSig functions.
		@param _id investor ID
		@param _allowed permission bool
		@return bool success
	 */
	function setInvestorRestriction(
		bytes32 _id,
		bool _allowed
	)
		external
		returns (bool)
	{
		if (!_checkMultiSig()) return false;
		accounts[_id].restricted = !_allowed;
		emit InvestorRestriction(_id, _allowed);
		return true;
	}

	/**
		@notice Set restriction on a token
		@dev
			Only the issuer can transfer restricted tokens. Useful in dealing
			with a security breach or a token migration.
		@param _token Address of the token
		@param _allowed permission bool
		@return bool success
	 */
	function setTokenRestriction(
		address _token,
		bool _allowed
	)
		external
		returns (bool)
	{
		if (!_checkMultiSig()) return false;
		require(tokens[_token].set);
		tokens[_token].restricted = !_allowed;
		emit TokenRestriction(_token, _allowed);
		return true;
	}

	/**
		@notice Set restriction on all tokens for this issuer
		@dev Only the issuer can transfer restricted tokens.
		@param _allowed permission bool
		@return bool success
	 */
	function setGlobalRestriction(bool _allowed) external returns (bool) {
		if (!_checkMultiSig()) return false;
		locked = !_allowed;
		emit GlobalRestriction(_allowed);
		return true;
	}

	/**
		@notice Attach a module to IssuingEntity or SecurityToken
		@dev
			Modules have a lot of permission and flexibility in what they
			can do. Only attach a module that has been properly auditted and
			where you understand exactly what it is doing.
			https://sft-protocol.readthedocs.io/en/latest/modules.html
		@param _target Address of the contract where the module is attached
		@param _module Address of the module contract
		@return bool success
	 */
	function attachModule(
		address _target,
		address _module
	)
		external
		returns (bool)
	{
		if (!_checkMultiSig()) return false;
		if (_target == address(this)) {
			_attachModule(_module);
		} else {
			require(tokens[_target].set);
			SecurityToken(_target).attachModule(_module);
		}
		return true;
	}

	/**
		@notice Detach a module from IssuingEntity or SecurityToken
		@dev This function may also be called by the module itself.
		@param _target Address of the contract where the module is attached
		@param _module Address of the module contract
		@return bool success
	 */
	function detachModule(
		address _target,
		address _module
	)
		external
		returns (bool)
	{
		if (_module != msg.sender) {
			if (!_checkMultiSig()) return false;
		}
		if (_target == address(this)) {
			_detachModule(_module);
		} else {
			require(tokens[_target].set);
			SecurityToken(_target).detachModule(_module);
		}
		return true;
	}

	/**
		@notice Remove an investor from a custodian's beneficial owners
		@dev Only callable by a custodian or the issuer
		@param _custID Custodian ID
		@param _id investor ID
		@return bool success
	 */
	function releaseOwnership(
		bytes32 _custID,
		bytes32 _id
	)
		external
		returns (bool)
	{
		/* custodian re-entrancy guard */
		require (!mutex);
		if (custodians[_custID].addr != msg.sender) {
			if (!_checkMultiSig()) return false;
		}
		_setBeneficialOwners(_custID, _id, false);
		return true;
	}

	function _setBeneficialOwners(
		bytes32 _custID,
		bytes32 _id,
		bool _add
	)
		internal
	{
		if (_id == ownerID || custodians[_id].addr != 0) return;
		Account storage a = accounts[_id];
		if (a.custodians[_custID] == _add) return;
		a.custodians[_custID] = _add;
		emit BeneficialOwnerSet(msg.sender, _id, _add);
		if (_add) {
			a.count = a.count.add(1);
			if (a.count == 1) {
				_incrementCount(
					a.rating,
					registrars[a.regKey].addr.getCountry(_id)
				);	
			}
		} else {
			a.count = a.count.sub(1);
			if (a.count == 0) {
				_decrementCount(
					a.rating,
					registrars[a.regKey].addr.getCountry(_id)
				);	
			}
		}
	}

}