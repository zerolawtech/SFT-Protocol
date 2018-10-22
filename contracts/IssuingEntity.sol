pragma solidity ^0.4.24;

import "./open-zeppelin/SafeMath.sol";
import "./SecurityToken.sol";
import "./STBase.sol";


/// @title Issuing Entity
contract IssuingEntity is STBase {

	using SafeMath64 for uint64;
	using SafeMath for uint256;

	/*
		Each country will have discrete limits for each investor class.
		minRating corresponds to investor accreditation levels:
			1 - unaccredited
			2 - accredited
			3 - qualified
	*/
	struct Country {
		bool allowed;
		uint8 minRating;
		mapping (uint8 => uint64) count;
		mapping (uint8 => uint64) limit;
	}

	struct Account {
		uint240 balance;
		uint8 rating;
		uint8 regKey;
		bool restricted;
	}

	mapping (address => bytes32) idMap;

	struct Registrar {
		KYCRegistrar registrar;
		bool restricted;
	}

	Registrar[] regArray;
	mapping (uint8 => uint64) investorCount;
	mapping (uint8 => uint64) investorLimit;
	mapping (uint16 => Country) countries;
	mapping (bytes32 => Account) accounts;
	mapping (address => bool) tokens;
	mapping (string => bytes32) documentHashes;

	mapping (address => bool) public issuerAddr;
	mapping (bytes32 => address[]) multiSigAuth;
	uint256 multiSigThreshold;

	event TransferOwnership(
		address token,
		bytes32 from,
		bytes32 to,
		uint256 value
	);
	event CountryApproved(uint16 country, uint8 minRating, uint64 limit);
	event CountryBlocked(uint16 country);
	event NewDocumentHash(string document, bytes32 hash);

	modifier onlyToken() {
		require (tokens[msg.sender]);
		_;
	}

	modifier onlyIssuer() {
		require (issuerAddr[msg.sender]);
		_;
	}

	/// @notice Issuing entity constructor
	/// @param _registrar Address of the registrar
	/// @param _id ID of Issuer
	constructor(address _registrar, bytes32 _id) public {
		registrar = KYCRegistrar(_registrar);
		issuerID = _id;
	}

	function _checkMultiSig() internal returns (bool) {
		bytes32 _callHash = keccak256(msg.data);
		if (multiSigAuth[_callHash].length.add(1) >= multiSigThreshold) {
			delete multiSigAuth[_callHash];
			return true;
		}
		for (uint256 i = 0; i < multiSigAuth[_callHash].length; i++) {
			require (multiSigAuth[_callHash][i] != msg.sender);
		}
		multiSigAuth[_callHash].push(msg.sender);
		return false;
	}

	/// @notice Fetch count of all investors, regardless of rating
	/// @return integer
	function totalInvestors() public view returns (uint64) {
		return investorCount[0];
	}

	/// @notice Fetch limit of all investors, regardless of rating
	/// @return integer
	function totalInvestorLimit() public view returns (uint64) {
		return investorLimit[0];
	}

	/// @notice Fetch balance of an investor, issuer, or exchange
	/// @param _id Account to query
	/// @return integer
	function balanceOf(bytes32 _id) public view returns (uint256) {
		return uint256(accounts[_id].balance);
	}

	/// @notice Fetch count of investors by country and rating
	/// @param _country Country to query
	/// @param _rating Rating to query
	/// @return integer
	function getCountryInvestorCount(
		uint16 _country,
		uint8 _rating
	)
		public
		view
		returns (uint64)
	{
		return countries[_country].count[_rating];
	}

	/// @notice Fetch limit of investors by country and rating
	/// @param _country Country to query
	/// @param _rating Rating to query
	/// @return integer
	function getCountryInvestorLimit(
		uint16 _country,
		uint8 _rating
	)
		public
		view
		returns (uint64)
	{
		return countries[_country].limit[_rating];
	}

	/// @notice Fetch count and limit of investors by country and rating
	/// in one call to preserve gas
	/// @param _country Country to query
	/// @param _rating Rating to query
	/// @return integer
	function getCountryInfo(
		uint16 _country,
		uint8 _rating
	)
		public
		view
		returns (uint64 _count, uint64 _limit)
	{
		return (
			countries[_country].count[_rating],
			countries[_country].limit[_rating]);
	}

	/// @notice Set investor limits
	/// @dev The first array entry (0) corresponds to the total investor limit,
	/// regardless of rating
	/// @param _limits Array of limits per rating
	function setInvestorLimits(uint64[] _limits) public onlyIssuer {
		for (uint8 i = 0; i < _limits.length; i++) {
			/*
				investorLimit[0] = combined sum of investorLimit[1] [2] and [3]
				investorLimit[1] = unaccredited
				investorLimit[2] = accredited
				investorLimit[3] = qualified
			*/
			investorLimit[i] = _limits[i];
		}
	}

	/// @notice Initialize countries so they can accept investors
	/// @param _country Array of counties to add
	/// @param _minRating Array of minimum investor ratings necessary for each country
	/// @param _limit Array of maximum mumber of investors allowed from this country
	function setCountries(
		uint16[] _country,
		uint8[] _minRating,
		uint64[] _limit
	)
		public
		onlyIssuer
	{
		require (_country.length == _minRating.length);
		require (_country.length == _limit.length);
		for (uint256 i = 0; i < _country.length; i++) {
			require (_minRating[i] != 0);
			Country storage c = countries[_country[i]];
			c.allowed = true;
			c.minRating = _minRating[i];
			c.limit[0] = _limit[i];
			emit CountryApproved(_country[i], _minRating[i], _limit[i]);
		}
	}

	/// @notice Block a country from all transactions
	/// @param _country Country to modify
	function blockCountry(uint16 _country) public onlyIssuer {
		countries[_country].allowed = false;
		emit CountryBlocked(_country);
	}

	/// @notice Set country investor limits after creation
	/// @param _country Country to modify
	/// @param _ratings Ratings to modify
	/// @param _limits New limits
	function setCountryInvestorLimits(
		uint16 _country,
		uint8[] _ratings,
		uint64[] _limits
	)
		public
		onlyIssuer
	{
		require (_ratings.length == _limits.length);
		Country storage c = countries[_country];
		require (c.allowed);
		for (uint256 i = 0; i < _ratings.length; i++) {
			require (_ratings[i] != 0);
			c.limit[_ratings[i]] = _limits[i];
		}
	}

	/// @notice Check if a transfer is possible at the issuing entity level
	/// @param _token Token being transferred
	/// @param _authId ID of the caller attempting the transfer
	/// @param _id Array of sender/receiver IDs
	/// @param _class Arracy of sender/receiver classes
	/// @param _country Array of sender/receiver countries
	/// @param _value Number of tokens being transferred
	/// @return boolean
	function checkTransfer(
		address _token,
		address _auth,
		address _from,
		address _to,
		uint256 _value
	)
		external
		view
		returns (bool)
	{
		if (issuerAddr[_auth]) {
			bytes32 _idAuth = issuerID;
		} else {
			_idAuth = _getId(_auth);
		}
		bytes32 _idFrom = _getId(_from);
		bytes32 _idTo = _getId(_to);
		
		(
			bool[2] _allowed,
			uint8[2] _rating,
			uint16[2] _country
		/*
			If authority is equal to from, check investor information of
			authority.  Otherwise, check for from
		*/
		) = _getInvestors((_idAuth == _idFrom ? _auth : _from), _to);
		if (!issuerAddr[_auth]) {
			require(!accounts[_idFrom].restricted);
			require(_allowed[0]);	
		}
		require(!accounts[_idTo].restricted);
		require(_allowed[1]);
		if (_idFrom != _idTo) {
			/* TODO Exchange to exchange transfers are not permitted */
			if (_idTo != 0) {
				Country storage c = countries[_country[1]];
			//	uint8 _rating = registrar.getRating(_id[1]);
				require (c.allowed);
				/*  
					If the receiving investor currently has a 0 balance,
					we must make sure a slot is available for allocation
				*/
				require (_rating[1] >= c.minRating);
				if (accounts[_idTo].balance == 0) {
					/*
						If the sender is an investor and still retains a balance,
						a new slot must be available
					*/
					bool _check = (
						_idTo != 0 ||
						accounts[_idTo].balance > _value
					);
					if (_check) {
						require (
							investorLimit[0] == 0 ||
							investorCount[0] < investorLimit[0]
						);
					}
					/*
						If the investors are from different countries, make sure
						a slot is available in the overall country limit
					*/
					if (_check || _country[0] != _country[1]) {
						require (c.limit[0] == 0 || c.count[0] < c.limit[0]);
					}
					if (!_check) {
						_check = _rating[0] != _rating[1];
					}
					/*
						If the investors are of different ratings, make sure a
						slot is available in the receiver's rating in the overall
						count
					*/
					if (_check) {
						require (
							investorLimit[_rating[1]] == 0 ||
							investorCount[_rating[1]] < investorLimit[_rating[1]]
						);
					}
					/*
						If the investors don't match in country or rating, make
						sure a slot is available in both the specific country
						and rating for the receiver
					*/
					if (_check || _country[0] != _country[1]) {
						require (
							c.limit[_rating[1]] == 0 ||
							c.count[_rating[1]] < c.limit[_rating[1]]
						);
					}
				}
			}
		}
		for (uint256 i = 0; i < modules.length; i++) {
			if (address(modules[i].module) != 0 && modules[i].checkTransfer) {
				require(IssuerModule(modules[i].module).checkTransfer(_token, _idAuth, bytes32[2]([_idFrom, _idTo]), _country, _rating, _value));
			}
		}
		return true;
	}


	function _getInvestors(
		address _from,
		address _to
	)
		internal
		returns 
	(
		bool[2] _allowed,
		uint8[2] _rating,
		uint16[2] _country
	) {
		bytes32[2] _id;
		if (accounts[idMap[_from]].regKey == accounts[idMap[_to]].regKey) {
			(_id, _allowed, _rating, _country) = accounts[idMap[_from]].registrar.getInvestors(_from, _to);
		} else {
			(_id[0], _allowed[0], _rating[0], _country[0]) = accounts[idMap[_from]].registrar.getInvestor(_from);
			(_id[0], _allowed[1], _rating[1], _country[1]) = accounts[idMap[_from]].registrar.getInvestor(_to);
		}
		return (_allowed, _rating, _country);
	}

	function _getId(address _addr) internal returns (bytes32) {
		bytes32 _id = idMap[_addr];
		if (_id == 0) {
			for (uint256 i = 0; i < Registrar.length; i++) {
				if (address(regArray[i].registrar) == 0) {
					continue;
				}
				_id = regArry[i].registrar.getId(_addr);
				if (_id == 0) {
					continue;
				}
				idMap[_addr] = _id;
				accounts[_id].regKey = uint8(i);
				return _id;
			}
			return 0;
		}
		if (address(regArray[accounts[_id].regKey].registrar) == 0)  {
			for (i = 0; i < Registrar.length; i++) {
				if (
					address(regArray[i].registrar) == 0 || 
					_id != regArray[i].registrar.getId(_addr)
				) {
					continue;
				}
				accounts[_id].regKey = uint8(i);
				return _id;
			}
			return 0;
		}
		return _id;
	}




	/// @notice Transfer tokens through the issuing entity level
	/// @param _id Array of sender/receiver IDs
	/// @param _class Arracy of sender/receiver classes
	/// @param _country Array of sender/receiver countries
	/// @param _value Number of tokens being transferred
	/// @return boolean
	function transferTokens(
		bytes32[2] _id,
		uint8[2] _class,
		uint16[2] _country,
		uint256 _value
	)
		external
		onlyUnlocked
		onlyToken
		returns (bool)
	{
		if (_id[0] == _id[1]) return true;
		uint _balance = uint256(accounts[_id[0]].balance).sub(_value);
		_setBalance(_id[0], _class[0], _country[0], _balance);
		_balance = uint256(accounts[_id[1]].balance).add(_value);
		_setBalance(_id[1], _class[1], _country[1], _balance);
		for (uint256 i = 0; i < modules.length; i++) {
			if (address(modules[i].module) != 0 && modules[i].transferTokens) {
				IssuerModule m = IssuerModule(modules[i].module);
				require (m.transferTokens(msg.sender, _id, _class, _country, _value));
			}
		}
		emit TransferOwnership(msg.sender, _id[0], _id[1], _value);
		return true;
	}

	/// @notice Affect a direct balance change (burn/mint) at the issuing entity level
	/// @param _owner Token owner
	/// @param _old Old balance
	/// @param _new New balance
	/// @return boolean
	function balanceChanged(
		address _owner,
		uint256 _old,
		uint256 _new
	)
		external
		onlyUnlocked
		onlyToken
		returns (bool)
	{
		(bytes32 _id, uint8 _class, uint16 _country) = registrar.getEntity(_owner);
		uint256 _oldTotal = accounts[_id].balance;
		if (_new > _old) {
			uint256 _newTotal = uint256(accounts[_id].balance).add(_new.sub(_old));
		} else {
			_newTotal = uint256(accounts[_id].balance).sub(_old.sub(_new));
		}
		_setBalance(_id, _class, _country, _newTotal);
		for (uint256 i = 0; i < modules.length; i++) {
			if (address(modules[i].module) != 0 && modules[i].balanceChanged) {
				IssuerModule m = IssuerModule(modules[i].module);
				require (m.balanceChanged(msg.sender, _id, _class, _country, _oldTotal, _newTotal));
			}
		}
		return true;
	}

	/// @notice Directly set a balance at the issuing entity level
	/// @param _id ID of affected entity
	/// @param _class Class of affected entity
	/// @param _country Country of affected entity
	/// @param _value New balance
	/// @return boolean
	function _setBalance(
		bytes32 _id,
		uint8 _class,
		uint16 _country,
		uint256 _value
	)
		internal
	{
		Account storage a = accounts[_id];
		Country storage c = countries[_country];
		if (_class == 1) {
			uint8 _rating = registrar.getRating(_id);
			if (_rating != a.rating) {
				if (a.rating > 0) {
					c.count[_rating] = c.count[_rating].sub(1);
					c.count[a.rating] = c.count[a.rating].add(1);
				}
				a.rating = _rating;
			}
			/* If this sets an investor account balance > 0, take an available slot */
			if (a.balance == 0) {
				investorCount[0] = investorCount[0].add(1);
				investorCount[_rating] = investorCount[_rating].add(1);
				c.count[0] = c.count[0].add(1);
				c.count[_rating] = c.count[_rating].add(1);
			/* If this sets an investor account balance to 0, add another available slot */
			} else if (_value == 0) {
				investorCount[0] = investorCount[0].sub(1);
				investorCount[_rating] = investorCount[_rating].sub(1);
				c.count[0] = c.count[0].sub(1);
				c.count[_rating] = c.count[_rating].sub(1);
			}
		}
		a.balance = uint248(_value);
	}

	
	/// @notice Add a new security token contract
	/// @param _token Token contract address
	/// @return bool
	function addToken(address _token) external onlyIssuer returns (bool) {
		SecurityToken token = SecurityToken(_token);
		require (!tokens[_token]);
		require (token.issuerID() == issuerID);
		require (token.circulatingSupply() == 0);
		tokens[_token] = true;
		uint256 _balance = uint256(accounts[issuerID].balance).add(token.treasurySupply());
		accounts[issuerID].balance = uint248(_balance);
		return true;
	}

	/// @notice Set document hash
	/// @param _documentId Document ID being hashed
	/// @param _hash Hash of the document
	function setDocumentHash(string _documentId, bytes32 _hash) public onlyIssuer {
		require (documentHashes[_documentId] == 0);
		documentHashes[_documentId] = _hash;
		emit NewDocumentHash(_documentId, _hash);
	}

	/// @notice Fetch document hash
	/// @param _documentId Document ID to fetch
	/// @return string
	function getDocumentHash(string _documentId) public view returns (bytes32) {
		return documentHashes[_documentId];
	}

	/// @notice Determines if a module is active on this issuing entity
	/// @param _module Deployed module address
	/// @return boolean
	function isActiveModule(address _module) public view returns (bool) {
		return activeModules[_module];
	}

	function addRegistrar(address _registrar) public onlyIssuer returns (bool) {
		for (uint256 i = 0; i < regArray.length; i++) {
			if (address(regArray[i].registrar) == _registrar) {
				regArray[i].restricted = false;
				return true;
			}
		}
		regArray.push(Registrar(KYCRegistrar(_registrar), false));
		return true;
	}

	function removeRegistrar(address _registrar) public onlyIssuer returns (bool) {
		for (uint256 i = 0; i < KycContracts.length; i++) {
			if (address(regArray[i].registrar) == _registrar) {
				regArray[i].restricted = true;
				return true;
			}
		}
		revert();
	}

}
