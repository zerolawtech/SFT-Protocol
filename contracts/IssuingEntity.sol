pragma solidity >=0.4.24 <0.5.0;

import "./open-zeppelin/SafeMath.sol";
import "./KYCRegistrar.sol";
import "./SecurityToken.sol";
import "./interfaces/IBaseCustodian.sol";
import "./interfaces/IGovernance.sol";
import "./bases/MultiSig.sol";

/** @title Issuing Entity */
contract IssuingEntity is MultiSig {

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
		bool permitted;
		uint8 minRating;
	}

	struct Account {
		uint32 count;
		uint8 rating;
		uint8 regKey;
		bool set;
		bool restricted;
		address custodian;
	}

	struct Token {
		bool set;
		bool restricted;
	}

	struct RegistrarContract {
		KYCRegistrar addr;
		bool restricted;
	}

	IGovernance public governance;
	bool locked;
	RegistrarContract[] registrars;
	uint32[8] counts;
	uint32[8] limits;
	mapping (uint16 => Country) countries;
	mapping (bytes32 => Account) accounts;
	mapping (address => Token) tokens;
	mapping (string => bytes32) documentHashes;

	event CountryModified(
		uint16 indexed country,
		bool permitted,
		uint8 minrating,
		uint32[8] limits
	);
	event InvestorLimitsSet(uint32[8] limits);
	event NewDocumentHash(string indexed document, bytes32 documentHash);
	event GovernanceSet(address indexed governance);
	event RegistrarSet(address indexed registrar, bool permitted);
	event CustodianAdded(address indexed custodian);
	event TokenAdded(address indexed token);
	event EntityRestriction(bytes32 indexed id, bool permitted);
	event TokenRestriction(address indexed token, bool permitted);
	event GlobalRestriction(bool permitted);

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
		idMap[address(this)].id = ownerID;
	}

	/**
		@notice Check if an address belongs to a registered investor
		@dev Retrurns false for custodian or issuer addresses
		@param _addr address to check
		@return bytes32 investor ID
	 */
	function isRegisteredInvestor(address _addr) external view returns (bool) {
		bytes32 _id = _getID(_addr);
		return accounts[_id].rating > 0;
	}

	/**
		@notice Check if a token is associated to this contract and unrestricted
		@param _token address to check
		@return boolean
	 */
	function isActiveToken(address _token) external view returns (bool) {
		return tokens[_token].set && !tokens[_token].restricted;
	}

	/**
		@notice External view to fetch an investor ID from an address
		@param _addr address to check
		@return bytes32 investor ID
	 */
	function getID(address _addr) external view returns (bytes32 _id) {
		_id = _getID(_addr);
		if (_id == ownerID) {
			return idMap[_addr].id;
		}
		return _id;
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
		@notice Fetch total investor counts and limits
		@return counts, limits
	 */
	function getInvestorCounts()
	external
	view
	returns (
		uint32[8] _counts,
		uint32[8] _limits
	)
	{
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
		@notice Fetch document hash
		@param _documentID Document ID to fetch
		@return document hash
	 */
	function getDocumentHash(string _documentID) external view returns (bytes32) {
		return documentHashes[_documentID];
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
		@notice Add a new security token contract
		@dev Requires permission from governance module
		@param _token Token contract address
		@return bool success
	 */
	function addToken(address _token) external returns (bool) {
		if (!_checkMultiSig()) return false;
		SecurityToken token = SecurityToken(_token);
		require(!tokens[_token].set, "dev: already set");
		require(token.ownerID() == ownerID, "dev: wrong owner");
		require(token.circulatingSupply() == 0);
		if (address(governance) != 0x00) {
			require(governance.addToken(_token), "Action has not been approved");
		}
		tokens[_token].set = true;
		emit TokenAdded(_token);
		return true;
	}

	/**
		@notice Add a new authority
		@param _addr Array of addressses to register as authority
		@param _signatures Array of bytes4 sigs this authority may call
		@param _approvedUntil Epoch time that authority is approved until
		@param _threshold Minimum number of calls to a method for multisig
		@return bool success
	 */
	function addAuthority(
		address[] _addr,
		bytes4[] _signatures,
		uint32 _approvedUntil,
		uint32 _threshold
	)
		public
		returns (bool)
	{
		require(!accounts[keccak256(abi.encodePacked(_addr))].set, "dev: known ID");
		super.addAuthority(_addr, _signatures, _approvedUntil, _threshold);
		return true;
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
		bytes32 _id = IBaseCustodian(_custodian).ownerID();
		require(_id != 0, "dev: zero ID");
		require(idMap[_custodian].id == 0, "dev: known address");
		require(!accounts[_id].set, "dev: known ID");
		require(authorityData[_id].addressCount == 0, "dev: authority ID");
		idMap[_custodian].id = _id;
		accounts[_id].custodian = _custodian;
		accounts[_id].set = true;
		emit CustodianAdded(_custodian);
		return true;
	}

	/**
		@notice Set the governance module
		@dev Setting the address to 0x00 is equivalent to disabling it
		@param _governance Governance module address
		@return bool success
	 */
	function setGovernance(IGovernance _governance) external returns (bool) {
		if (!_checkMultiSig()) return false;
		if (address(_governance) != 0x00) {
			require (_governance.issuer() == address(this), "dev: wrong issuer");
		}
		governance = _governance;
		emit GovernanceSet(_governance);
		return true;
	}

	/**
		@notice Attach or remove a KYCRegistrar contract
		@param _registrar address of registrar
		@param _permitted registrar permission
		@return bool success
	 */
	function setRegistrar(
		KYCRegistrar _registrar,
		bool _permitted
	)
		external
		returns (bool)
	{
		if (!_checkMultiSig()) return false;
		for (uint256 i = 1; i < registrars.length; i++) {
			if (registrars[i].addr == _registrar) {
				registrars[i].restricted = !_permitted;
				emit RegistrarSet(_registrar, _permitted);
				return true;
			}
		}
		if (_permitted) {
			registrars.push(RegistrarContract(_registrar, false));
			emit RegistrarSet(_registrar, _permitted);
			return true;
		}
		revert();
	}

	/**
		@notice Set all information about a country
		@param _country Country to modify
		@param _permitted Is country approved
		@param _minRating minimum investor rating
		@param _limits array of investor limits
		@return bool success
	 */
	function setCountry(
		uint16 _country,
		bool _permitted,
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
		c.permitted = _permitted;
		emit CountryModified(_country, _permitted, _minRating, _limits);
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
		for (uint256 i; i < _country.length; i++) {
			require(_minRating[i] != 0);
			Country storage c = countries[_country[i]];
			c.permitted = true;
			c.minRating = _minRating[i];
			c.limits[0] = _limit[i];
			emit CountryModified(_country[i], true, _minRating[i], c.limits);
		}
		return true;
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
	function setInvestorLimits(uint32[8] _limits) external returns (bool) {
		if (!_checkMultiSig()) return false;
		limits = _limits;
		emit InvestorLimitsSet(_limits);
		return true;
	}

	/**
		@notice Set restriction on an investor or custodian ID
		@dev restrictions on sub-authorities are handled via MultiSig methods
		@param _id investor ID
		@param _permitted permission bool
		@return bool success
	 */
	function setEntityRestriction(
		bytes32 _id,
		bool _permitted
	)
		external
		returns (bool)
	{
		if (!_checkMultiSig()) return false;
		require(authorityData[_id].addressCount == 0, "dev: authority");
		accounts[_id].restricted = !_permitted;
		emit EntityRestriction(_id, _permitted);
		return true;
	}

	/**
		@notice Set restriction on a token
		@dev
			Only the issuer can transfer restricted tokens. Useful in dealing
			with a security breach or a token migration.
		@param _token Address of the token
		@param _permitted permission bool
		@return bool success
	 */
	function setTokenRestriction(
		address _token,
		bool _permitted
	)
		external
		returns (bool)
	{
		if (!_checkMultiSig()) return false;
		require(tokens[_token].set);
		tokens[_token].restricted = !_permitted;
		emit TokenRestriction(_token, _permitted);
		return true;
	}

	/**
		@notice Set restriction on all tokens for this issuer
		@dev Only the issuer can transfer restricted tokens.
		@param _permitted permission bool
		@return bool success
	 */
	function setGlobalRestriction(bool _permitted) external returns (bool) {
		if (!_checkMultiSig()) return false;
		locked = !_permitted;
		emit GlobalRestriction(_permitted);
		return true;
	}

	/**
		@notice Check if transfer is possible based on issuer level restrictions
		@dev function is not called directly - see SecurityToken.checkTransfer
		@param _auth address of the caller attempting the transfer
		@param _from address of the sender
		@param _to address of the receiver
		@param _zero is the sender's balance zero after the transfer?
		@return bytes32 ID of caller
		@return bytes32[] IDs of sender and receiver
		@return uint8[] ratings of sender and receiver
		@return uint16[] countries of sender and receiver
	 */
	function checkTransfer(
		address _auth,
		address _from,
		address _to,
		bool _zero
	)
		public
		returns (
			bytes32 _authID,
			bytes32[2] _id,
			uint8[2] _rating,
			uint16[2] _country
		)
	{
		_authID = _getID(_auth);
		_id[0] = _getID(_from);
		_id[1] = _getID(_to);
		
		if (_authID == ownerID && idMap[_auth].id != ownerID) {
			/* This enforces sub-authority permissioning around transfers */
			Authority storage a = authorityData[idMap[_auth].id];
			require(
				a.approvedUntil >= now &&
				a.signatures[bytes4(_authID == _id[0] ? 0xa9059cbb : 0x23b872dd)],
				"Authority not permitted"
			);
		}

		address _addr = (_authID == _id[0] ? _auth : _from);
		bool[2] memory _permitted;

		(_permitted, _rating, _country) = _getInvestors(
			[_addr, _to],
			[accounts[idMap[_addr].id].regKey, accounts[_id[1]].regKey]
		);
		if (accounts[_authID].custodian != 0) {
			require(accounts[_id[1]].custodian == 0, "Custodian to Custodian");
		}

		/* must be allowed to underflow in case of issuer zero balance */
		uint32 _count = accounts[_id[0]].count;
		if (_zero) _count -= 1;

		_checkTransfer(_authID, _id, _permitted, _rating, _country, _count);
		return (_authID, _id, _rating, _country);
	}

	/**
		@notice internal investor ID fetch
		@param _addr Investor address
		@return bytes32 investor ID
	 */
	function _getID(address _addr) internal returns (bytes32 _id) {
		_id = idMap[_addr].id;
		if (authorityData[_id].addressCount > 0) {
			require(!idMap[_addr].restricted, "Restricted Authority Address");
			return ownerID;
		}
		if (
			(
				accounts[_id].regKey > 0 &&
				!registrars[accounts[_id].regKey].restricted
			) || accounts[_id].custodian != 0
		) {
			return _id;
		}
		if (_id == 0) {
			for (uint256 i = 1; i < registrars.length; i++) {
				if (!registrars[i].restricted) {
					_id = registrars[i].addr.getID(_addr);
					/* prevent investor / authority ID collisions */
					if (_id != 0 && authorityData[_id].addressCount == 0) {
						idMap[_addr].id = _id;
						if (!accounts[_id].set) {
							accounts[_id].set = true;
							accounts[_id].regKey = uint8(i);
						} else if (accounts[_id].regKey != i) {
							continue;
						}
						accounts[_id].regKey = uint8(i);
						return _id;
					}
				}
			}
		} else {
			for (i = 1; i < registrars.length; i++) {
				if (registrars[i].restricted) continue;
				if (_id != registrars[i].addr.getID(_addr)) continue;
				accounts[_id].regKey = uint8(i);
				return _id;
			}
			revert("Registrar restricted");
		}
		revert("Address not registered");
	}

	/**
		@notice Internal function for fetching investor data from registrars
		@dev Either _addr or _id may be given as an empty array
		@param _addr array of investor addresses
		@param _key array of registrar indexes
		@return permissions, ratings, and countries of investors
	 */
	function _getInvestors(
		address[2] _addr,
		uint8[2] _key
	)
		internal
		view
		returns (
			bool[2] _permitted,
			uint8[2] _rating,
			uint16[2] _country
		)
	{
		/* If both investors are in the same registry, call getInvestors */
		KYCRegistrar r = registrars[_key[0]].addr;
		if (_key[0] > 0 && _key[0] == _key[1]) {
			(, _permitted, _rating, _country) = r.getInvestors(_addr[0], _addr[1]);
			return (_permitted, _rating, _country);
		}
		/* Otherwise, call getInvestor at each registry */
		if (_key[0] != 0) {
			(, _permitted[0], _rating[0], _country[0]) = r.getInvestor(_addr[0]);
		} else {
			/* If key == 0 the address belongs to the issuer or a custodian. */
			_permitted[0] = true;
		}
		if (_key[1] != 0) {
			r = registrars[_key[1]].addr;
			(, _permitted[1], _rating[1], _country[1]) = r.getInvestor(_addr[1]);
		} else {
			_permitted[1] = true;
		}
		return (_permitted, _rating, _country);
	}

	/**
		@notice internal check if transfer is permitted
		@param _authID id hash of caller
		@param _id addresses of sender and receiver
		@param _permitted array of permission bools from registrar
		@param _rating array of investor ratings
		@param _country array of investor countries
		@param _tokenCount sender accounts.count value after transfer
	 */
	function _checkTransfer(
		bytes32 _authID,
		bytes32[2] _id,
		bool[2] _permitted,
		uint8[2] _rating,
		uint16[2] _country,
		uint32 _tokenCount
	)
		internal
		view
	{	
		require(tokens[msg.sender].set);
		/* If issuer is not the authority, check the sender is not restricted */
		if (_authID != ownerID) {
			require(!locked, "Transfers locked: Issuer");
			require(!tokens[msg.sender].restricted, "Transfers locked: Token");
			require(!accounts[_id[0]].restricted, "Sender restricted: Issuer");
			require(_permitted[0], "Sender restricted: Registrar");
			require(!accounts[_authID].restricted, "Authority restricted");
		}
		/* Always check the receiver is not restricted. */
		require(!accounts[_id[1]].restricted, "Receiver restricted: Issuer");
		require(_permitted[1], "Receiver restricted: Registrar");
		if (_id[0] != _id[1]) {
			/*
				A rating of 0 implies the receiver is the issuer or a
				custodian, no further checks are needed.
			*/
			if (_rating[1] != 0) {
				Country storage c = countries[_country[1]];
				require(c.permitted, "Receiver blocked: Country");
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
	}

	/**
		@notice Transfer tokens through the issuing entity level
		@dev only callable through SecurityToken
		@param _auth Caller address
		@param _from Sender address
		@param _to Receiver address
		@param _zero Array of zero balance booleans
			Is sender balance now zero?
			Was receiver balance zero?
			Is sender custodial balance now zero?
			Was receiver custodial balance zero?
		@return authority ID, IDs/ratings/countries for sender/receiver
	 */
	function transferTokens(
		address _auth,
		address _from,
		address _to,
		bool[4] _zero
	)
		external
		returns (
			bytes32 _authID,
			bytes32[2] _id,
			uint8[2] _rating,
			uint16[2] _country
		)
	{
		(_authID, _id, _rating, _country) = checkTransfer(_auth, _from, _to, _zero[0]);

		/* If no transfer of ownership, return true immediately */
		if (_id[0] == _id[1]) return;

		/* if sender is a normal investor */
		if (_rating[0] != 0) {
			_setRating(_id[0], _rating[0], _country[0]);
			if (_zero[0]) {
				Account storage a = accounts[_id[0]];
				a.count = a.count.sub(1);
				/* If investor account balance is now 0, lower investor counts */
				if (a.count == 0) {
					_decrementCount(_rating[0], _country[0]);
				}
			}
		/* if receiver is not the issuer, and sender is a custodian */
		} else if (_id[0] != ownerID && _id[1] != ownerID) {
			if (_zero[2]) {
				a = accounts[_id[1]];
				a.count = a.count.sub(1);
				if (a.count == 0) {
					_decrementCount(_rating[1], _country[1]);
				}
			}
		}
		/* if receiver is a normal investor */
		if (_rating[1] != 0) {
			_setRating(_id[1], _rating[1], _country[1]);
			if (_zero[1]) {
				a = accounts[_id[1]];
				a.count = a.count.add(1);
				/* If investor account balance was 0, increase investor counts */
				if (a.count == 1) {
					_incrementCount(_rating[1], _country[1]);
				}
			}
		/* if sender is not the issuer, and receiver is a custodian */
		} else if (_id[0] != ownerID && _id[1] != ownerID) {
			if (_zero[3]) {
				a = accounts[_id[0]];
				a.count = a.count.add(1);
				if (a.count == 1) {
					_incrementCount(_rating[0], _country[0]);
				}
			}
		}
		return (_authID, _id, _rating, _country);
	}

	/**
		@notice Affect a direct balance change (burn/mint) at the issuing entity level
		@dev This can only be called by a token
		@param _owner Token owner
		@param _old Old balance
		@param _new New balance
		@return id, rating, and country of the affected investor
	 */
	function modifyTokenTotalSupply(
		address _owner,
		uint256 _old,
		uint256 _new
	)
		external
		returns (
			bytes32 _id,
			uint8 _rating,
			uint16 _country
		)
	{
		require(tokens[msg.sender].set);
		require(!tokens[msg.sender].restricted);
		if (_owner == address(this)) {
			_id = ownerID;
		} else {
			require(accounts[idMap[_owner].id].custodian == 0, "dev: custodian");
			uint8 _key = accounts[idMap[_owner].id].regKey;
			(_id, , _rating, _country) = registrars[_key].addr.getInvestor(_owner);
		}
		Account storage a = accounts[_id];
		if (_id != ownerID) {
			_setRating(_id, _rating, _country);
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
		}
		return (_id, _rating, _country);
	}

	/**
		@notice Check and modify an investor's rating in contract storage
		@param _id Investor ID
		@param _rating Investor rating
		@param _country Investor country
	 */
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
		@notice Modify authorized supply
		@dev Called by a token, requires permission from governance module
		@param _value New authorized supply value
		@return bool
	 */
	function modifyAuthorizedSupply(uint256 _value) external returns (bool) {
		require(tokens[msg.sender].set);
		require(!tokens[msg.sender].restricted);
		if (address(governance) != 0x00) {
			require(
				governance.modifyAuthorizedSupply(msg.sender, _value),
				"Action has not been approved"
			);
		}
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
		IBaseModule _module
	)
		external
		returns (bool)
	{
		if (!_checkMultiSig()) return false;
		address _owner = _module.getOwner();
		require(tokens[_target].set, "dev: unknown target");
		require (_owner == _target || _owner == address(this), "dev: wrong owner");
		require(SecurityToken(_target).attachModule(_module));
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
		if (!_checkMultiSig()) return false;
		require(tokens[_target].set, "dev: unknown target");
		require(SecurityToken(_target).detachModule(_module));
		return true;
	}

}
