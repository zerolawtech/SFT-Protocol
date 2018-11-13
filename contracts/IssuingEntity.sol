pragma solidity ^0.4.24;

import "./open-zeppelin/SafeMath.sol";
import "./SecurityToken.sol";
import "./STBase.sol";
import "./interfaces/Custodian.sol";
import "./MultiSig.sol";

/// @title Issuing Entity
contract IssuingEntity is STBase, MultiSigMultiOwner {

	using SafeMath64 for uint64;
	using SafeMath for uint256;

	struct InvestorCount {
		uint64 count;
		uint64 limit;
	}

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
		mapping (uint8 => InvestorCount) counts;
	}

	struct Account {
		uint240 balance;
		uint8 rating;
		uint8 regKey;
		bool restricted;
		address registrar;
	}

	struct Token {
		bool set;
		bool restricted;
	}

	struct Registrar {
		KYCRegistrar registrar;
		bool restricted;
	}

	bool locked;
	Registrar[] regArray;
	mapping (uint8 => InvestorCount) counts;
	mapping (uint16 => Country) countries;
	mapping (bytes32 => Account) accounts;
	mapping (address => bytes32) idMap;
	mapping (address => Token) tokens;
	mapping (string => bytes32) documentHashes;

	event NewIssuingEntity(address creator, address contractAddr, bytes32 id);
	event TransferOwnership(
		address indexed token,
		bytes32 indexed from,
		bytes32 indexed to,
		uint256 value
	);
	event CountryApproved(uint16 indexed country, uint8 minRating, uint64 limit);
	event CountryBlocked(uint16 indexed country);
	event InvestorLimitSet(uint16 indexed country, uint8 rating, uint64 limit);
	event NewDocumentHash(string indexed document, bytes32 documentHash);
	event RegistrarAdded(address indexed registrar);
	event RegistrarRemoved(address indexed registrar);
	event CustodianAdded(address indexed custodian);
	event TokenAdded(address indexed token);
	event InvestorRestricted(bytes32 indexed id, bool restricted);
	event TokenRestricted(address indexed token, bool restricted);
	event GloballyRestricted(bool restricted);
	
	modifier onlyToken() {
		require (tokens[msg.sender].set && !tokens[msg.sender].restricted);
		_;
	}
	
	modifier onlyUnlocked() {
		require (!locked || authorityMap[msg.sender].id != 0);
		_;
	}

	/// @notice Issuing entity constructor
	constructor(
		address[] _owners,
		uint64 _threshold
	)
		MultiSigMultiOwner(_owners, _threshold)
		public 
	{
		regArray.push(Registrar(KYCRegistrar(0),false));
		emit NewIssuingEntity(msg.sender, address(this), ownerID);
	}

	/// @notice Fetch count of all investors, regardless of rating
	/// @return integer
	function totalInvestors() external view returns (uint64) {
		return counts[0].count;
	}

	/// @notice Fetch limit of all investors, regardless of rating
	/// @return integer
	function totalInvestorLimit() external view returns (uint64) {
		return counts[0].limit;
	}

	/// @notice Fetch balance of an investor, issuer, or exchange
	/// @param _id Account to query
	/// @return integer
	function balanceOf(bytes32 _id) external view returns (uint256) {
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
		external
		view
		returns (uint64)
	{
		return countries[_country].counts[_rating].count;
	}

	/// @notice Fetch limit of investors by country and rating
	/// @param _country Country to query
	/// @param _rating Rating to query
	/// @return integer
	function getCountryInvestorLimit(
		uint16 _country,
		uint8 _rating
	)
		external
		view
		returns (uint64)
	{
		return countries[_country].counts[_rating].limit;
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
		external
		view
		returns (uint64 _count, uint64 _limit)
	{
		return (
			countries[_country].counts[_rating].count,
			countries[_country].counts[_rating].limit
		);
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
		external
		returns (bool)
	{
		if (!_checkMultiSig()) {
			return false;
		}
		require (_country.length == _minRating.length);
		require (_country.length == _limit.length);
		for (uint256 i = 0; i < _country.length; i++) {
			require (_minRating[i] != 0);
			Country storage c = countries[_country[i]];
			c.allowed = true;
			c.minRating = _minRating[i];
			c.counts[0].limit = _limit[i];
			emit CountryApproved(_country[i], _minRating[i], _limit[i]);

		}
	}

	/// @notice Block a country from all transactions
	/// @param _country Country to modify
	function blockCountry(uint16 _country) external returns (bool) {
		if (!_checkMultiSig()) {
			return false;
		}
		countries[_country].allowed = false;
		emit CountryBlocked(_country);
		return true;
	}

	/// @notice Set investor limits
	/// @dev The first array entry (0) corresponds to the total investor limit,
	/// regardless of rating
	/// @param _limits Array of limits per rating
	function setInvestorLimits(
		uint64[] _limits
	)
		external
		returns (bool)
	{
		if (!_checkMultiSig()) {
			return false;
		}
		for (uint8 i = 0; i < _limits.length; i++) {
			/*
				investorLimit[0] = combined sum of investorLimit[1] [2] and [3]
				investorLimit[1] = unaccredited
				investorLimit[2] = accredited
				investorLimit[3] = qualified
			*/
			counts[i].limit = _limits[i];
			emit InvestorLimitSet(0, i, _limits[i]);
		}
		return true;
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
		external
		returns (bool)
	{
		if (!_checkMultiSig()) {
			return false;
		}
		require (_ratings.length == _limits.length);
		Country storage c = countries[_country];
		require (c.allowed);
		for (uint256 i = 0; i < _ratings.length; i++) {
			require (_ratings[i] != 0);
			c.counts[_ratings[i]].limit = _limits[i];
			emit InvestorLimitSet(_country, uint8(i), _limits[i]);
		}
		return true;
	}

	/// @notice Check if a transfer is possible at the issuing entity level
	/// @param _token Token being transferred
	/// @param _auth address of the caller attempting the transfer
	/// @param _from address of the sender
	/// @param _to address of the receiver
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
		returns (
			bytes32 _idAuth,
			bytes32[2] _id,
			uint8[2] _rating,
			uint16[2] _country
		)
	{
		_idAuth = _getId(_auth);
		_id[0] = _getId(_from);
		_id[1] = _getId(_to);
		
		if (authorityMap[_auth].id != 0 && authorityMap[_auth].id != ownerID) {
			/* bytes4 signatures of transfer, transferFrom */
			require(authorityData[authorityMap[_auth].id].approvedUntil >= now);
			require(authorityData[authorityMap[_auth].id].signatures[(_idAuth == _id[0] ? bytes4(0xa9059cbb) : bytes4(0x23b872dd))]);
		}

		address _addr = (_idAuth == _id[0] ? _auth : _from);
		bool[2] memory _allowed;

		(_allowed, _rating, _country) = _getInvestors(
			address[2]([_addr, _to]),
			uint8[2]([accounts[idMap[_addr]].regKey, accounts[idMap[_to]].regKey])
		);
		_checkTransfer(_token, _idAuth, _id, _allowed, _rating, _country, _value);
		return (_idAuth, _id, _rating, _country);
	}	
		
	function checkTransferView(
		address _token,
		address _from,
		address _to,
		uint256 _value
	)
		external
		view
		returns (
			bytes32[2] _id,
			uint8[2] _rating,
			uint16[2] _country
		)
	{
		if (authorityMap[_from].id != 0 && authorityMap[_from].id != ownerID) {
			require(authorityData[authorityMap[_from].id].approvedUntil >= now);
			require(authorityData[authorityMap[_from].id].signatures[0xa9059cbb]);
		}
		
		uint8[2] memory _key;
		(_id[0], _key[0]) = _getIdView(_from);
		(_id[1], _key[1]) = _getIdView(_to);

		address[2] memory _addr = [_from, _to];
		bool[2] memory _allowed;

		(_allowed, _rating, _country) = _getInvestors(_addr, _key);
		_checkTransfer(_token, _id[0], _id, _allowed, _rating, _country, _value);
		return (_id, _rating, _country);
	}

	function _checkTransfer(
		address _token,
		bytes32 _idAuth,
		bytes32[2] _id,
		bool[2] _allowed,
		uint8[2] _rating,
		uint16[2] _country,
		uint256 _value
	)
		internal
		view
	{	
		require(tokens[_token].set);
		/* If issuer is not the authority, check the sender is not restricted */
		if (_id[0] != ownerID) {
			require(!tokens[_token].restricted);
			require(!locked);
			require(!accounts[_id[0]].restricted);
			require(_allowed[0]);	
		}
		/* Always check the receiver is not restricted. */
		require(!accounts[_id[1]].restricted);
		require(_allowed[1]);
		if (_id[0] != _id[1]) {
			/* TODO Exchange to exchange transfers are not permitted */
			if (_rating[1] != 0) {
				Country storage c = countries[_country[1]];
				require (c.allowed);
				/*  
					If the receiving investor currently has a 0 balance,
					we must make sure a slot is available for allocation
				*/
				require (_rating[1] >= c.minRating);
				if (accounts[_id[1]].balance == 0) {
					/*
						If the sender is an investor and still retains a balance,
						a new slot must be available
					*/
					bool _check = (
						_rating[0] != 0 ||
						accounts[_id[1]].balance > _value
					);
					if (_check) {
						require (
							counts[0].limit == 0 ||
							counts[0].count < counts[0].limit
						);
					}
					/*
						If the investors are from different countries, make sure
						a slot is available in the overall country limit
					*/
					if (_check || _country[0] != _country[1]) {
						require (
							c.counts[0].limit == 0 ||
							c.counts[0].count < c.counts[0].limit
						);
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
							counts[_rating[1]].limit == 0 ||
							counts[_rating[1]].count < counts[_rating[1]].limit
						);
					}
					/*
						If the investors don't match in country or rating, make
						sure a slot is available in both the specific country
						and rating for the receiver
					*/
					if (_check || _country[0] != _country[1]) {
						require (
							c.counts[_rating[1]].limit == 0 ||
							c.counts[_rating[1]].count < c.counts[_rating[1]].limit
						);
					}
				}
			}
		}
		for (uint256 i = 0; i < modules.length; i++) {
			if (address(modules[i].module) != 0 && modules[i].checkTransfer) {
				require(IIssuerModule(modules[i].module).checkTransfer(_token, _idAuth, _id, _rating, _country, _value));
			}
		}
	}

	function getId(address _addr) external view returns (bytes32) {
		(bytes32 _id, uint8 _key) = _getIdView(_addr);
		return _id;
	}

	function _getId(address _addr) internal returns (bytes32) {
		(bytes32 _id, uint8 _key) = _getIdView(_addr);
		if (idMap[_addr] == 0 && authorityMap[_addr].id == 0) {
			idMap[_addr] = _id;
		}
		if (accounts[_id].regKey != _key) {
			accounts[_id].regKey = _key;
		}
		return _id;
	}

	function _getIdView(address _addr) internal view returns (bytes32, uint8) {
		if (authorityMap[_addr].id != 0 || _addr == address(this)) {
			return (ownerID, 0);
		}
		bytes32 _id = idMap[_addr];
		if (_id == 0) {
			for (uint256 i = 1; i < regArray.length; i++) {
				if (address(regArray[i].registrar) == 0) {
					continue;
				}
				_id = regArray[i].registrar.getId(_addr);
				if (_id != 0) {
					return (_id, uint8(i));
				}
				
			}
			revert();
		}
		if (accounts[_id].registrar != 0) {
			return (_id, 0);
		}
		if (address(regArray[accounts[_id].regKey].registrar) == 0)  {
			for (i = 1; i < regArray.length; i++) {
				if (
					address(regArray[i].registrar) != 0 && 
					_id == regArray[i].registrar.getId(_addr)
				) {
					return (_id, uint8(i));
				}
			}
			revert();
		}
		return (_id, accounts[_id].regKey);
	}

	function _getInvestors(
		address[2] _addr,
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
		bytes32[2] memory _id;
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
		
		if (_key[0] == _key[1] && _key[0] != 0) {
			(
				_id,
				_allowed,
				_rating,
				_country
			) = regArray[_key[0]].registrar.getInvestors(_addr[0], _addr[1]);
		} else {
			if (_key[0] != 0) {
				(
					_id[0],
					_allowed[0],
					_rating[0],
					_country[0]
				) = regArray[_key[0]].registrar.getInvestor(_addr[0]);
			}
			if (_key[1] != 0) {
				(
					_id[1],
					_allowed[1],
					_rating[1],
					_country[1]
				) = regArray[_key[1]].registrar.getInvestor(_addr[1]);
			}	
		}
		return (_allowed, _rating, _country);
	}

	/// @notice Transfer tokens through the issuing entity level
	/// @param _id Array of sender/receiver IDs
	/// @param _rating Arracy of sender/receiver ratings
	/// @param _country Array of sender/receiver countries
	/// @param _value Number of tokens being transferred
	/// @return boolean
	function transferTokens(
		bytes32[2] _id,
		uint8[2] _rating,
		uint16[2] _country,
		uint256 _value
	)
		external
		onlyToken
		returns (bool)
	{
		if (_id[0] == _id[1]) return true;
		uint _balance = uint256(accounts[_id[0]].balance).sub(_value);
		_setBalance(_id[0], _rating[0], _country[0], _balance);
		_balance = uint256(accounts[_id[1]].balance).add(_value);
		_setBalance(_id[1], _rating[1], _country[1], _balance);
		for (uint256 i = 0; i < modules.length; i++) {
			if (address(modules[i].module) != 0 && modules[i].transferTokens) {
				IIssuerModule m = IIssuerModule(modules[i].module);
				require (
					m.transferTokens(msg.sender, _id, _rating, _country, _value)
				);
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
			uint8 _key = accounts[idMap[_owner]].regKey;
			(
				_id,
				_allowed,
				_rating,
				_country
			) = regArray[_key].registrar.getInvestor(_owner);
		}
		uint256 _oldTotal = accounts[_id].balance;
		if (_new > _old) {
			uint256 _newTotal = uint256(accounts[_id].balance).add(_new.sub(_old));
		} else {
			_newTotal = uint256(accounts[_id].balance).sub(_old.sub(_new));
		}
		_setBalance(_id, _rating, _country, _newTotal);
		for (uint256 i = 0; i < modules.length; i++) {
			if (address(modules[i].module) != 0 && modules[i].balanceChanged) {
				IIssuerModule m = IIssuerModule(modules[i].module);
				require (m.balanceChanged(msg.sender, _id, _rating, _country, _oldTotal, _newTotal));
			}
		}
		return (_id, _rating, _country);
	}

	/// @notice Directly set a balance at the issuing entity level
	/// @param _id ID of affected entity
	/// @param _country Country of affected entity
	/// @param _value New balance
	/// @return boolean
	function _setBalance(
		bytes32 _id,
		uint8 _rating,
		uint16 _country,
		uint256 _value
	)
		internal
	{
		Account storage a = accounts[_id];
		Country storage c = countries[_country];
		if (_id != ownerID) {
			if (_rating != a.rating) {
				if (a.rating > 0) {
					c.counts[_rating].count = c.counts[_rating].count.sub(1);
					c.counts[a.rating].count = c.counts[a.rating].count.add(1);
				}
				a.rating = _rating;
			}
			/* If this sets an investor account balance > 0, take an available slot */
			if (a.balance == 0) {
				counts[0].count = counts[0].count.add(1);
				counts[_rating].count = counts[_rating].count.add(1);
				c.counts[0].count = c.counts[0].count.add(1);
				c.counts[_rating].count = c.counts[_rating].count.add(1);
			/* If this sets an investor account balance to 0, add another available slot */
			} else if (_value == 0) {
				counts[0].count = counts[0].count.sub(1);
				counts[_rating].count = counts[_rating].count.sub(1);
				c.counts[0].count = c.counts[0].count.sub(1);
				c.counts[_rating].count = c.counts[_rating].count.sub(1);
			}
		}
		a.balance = uint240(_value);
	}

	/// @notice Set document hash
	/// @param _documentId Document ID being hashed
	/// @param _hash Hash of the document
	function setDocumentHash(
		string _documentId,
		bytes32 _hash
	)
		external
		onlyOwner
		returns (bool)
	{
		if (!_checkMultiSig()) {
			return false;
		}
		require (documentHashes[_documentId] == 0);
		documentHashes[_documentId] = _hash;
		emit NewDocumentHash(_documentId, _hash);
		return true;
	}

	/// @notice Fetch document hash
	/// @param _documentId Document ID to fetch
	/// @return string
	function getDocumentHash(string _documentId) external view returns (bytes32) {
		return documentHashes[_documentId];
	}

	function addRegistrar(address _registrar) external returns (bool) {
		if (!_checkMultiSig()) {
			return false;
		}
		for (uint256 i = 1; i < regArray.length; i++) {
			if (address(regArray[i].registrar) == _registrar) {
				regArray[i].restricted = false;
				emit RegistrarAdded(_registrar);
				return true;
			}
		}
		regArray.push(Registrar(KYCRegistrar(_registrar), false));
		emit RegistrarAdded(_registrar);
		return true;
	}

	function removeRegistrar(address _registrar) external returns (bool) {
		if (!_checkMultiSig()) {
			return false;
		}
		for (uint256 i = 1; i < regArray.length; i++) {
			if (address(regArray[i].registrar) == _registrar) {
				regArray[i].restricted = true;
				emit RegistrarRemoved(_registrar);
				return true;
			}
		}
		revert();
	}

	function getRegistrar(bytes32 _id) external view returns (address) {
		return regArray[accounts[_id].regKey].registrar;
	}

	function addCustodian(address _addr) external returns (bool) {
		if (!_checkMultiSig()) {
			return false;
		}
		bytes32 _id = ICustodian(_addr).id();
		idMap[_addr] = _id;
		accounts[_id].registrar = _addr;
		emit CustodianAdded(_addr);
	}

	function setInvestorRestriction(
		bytes32 _id,
		bool _restricted
	)
		external
		returns (bool)
	{
		if (!_checkMultiSig()) {
			return false;
		}
		accounts[_id].restricted = _restricted;
		emit InvestorRestricted(_id, _restricted);
	}

	/// @notice Add a new security token contract
	/// @param _token Token contract address
	/// @return bool
	function addToken(address _token) external returns (bool) {
		if (!_checkMultiSig()) {
			return false;
		}
		SecurityToken token = SecurityToken(_token);
		require (!tokens[_token].set);
		require (token.ownerID() == ownerID);
		require (token.circulatingSupply() == 0);
		tokens[_token].set = true;
		uint256 _balance = uint256(accounts[ownerID].balance).add(token.treasurySupply());
		accounts[ownerID].balance = uint240(_balance);
		emit TokenAdded(_token);
		return true;
	}

	function setGlobalRestriction(bool _restricted) external returns (bool) {
		if (!_checkMultiSig()) {
			return false;
		}
		locked = _restricted;
		emit GloballyRestricted(_restricted);
		return true;
	}

	function setTokenRestriction(
		address _token,
		bool _restricted
	)
		external
		returns (bool)
	{
		if (!_checkMultiSig()) {
			return false;
		}
		require (tokens[_token].set);
		tokens[_token].restricted = _restricted;
		emit TokenRestricted(_token, _restricted);
		return true;
	}

	/// @notice Determines if a module is active on this issuing entity
	/// @param _module Deployed module address
	/// @return boolean
	function isActiveModule(address _module) external view returns (bool) {
		return activeModules[_module];
	}

	function attachModule(
		address _target,
		address _module
	)
		external
		returns (bool)
	{
		if (!_checkMultiSig()) {
			return false;
		}
		if (_target == address(this)) {
			_attachModule(_module);
		} else {
			require (tokens[_target].set);
			SecurityToken(_target).attachModule(_module);
		}
		return true;
	}

	function detachModule(
		address _target,
		address _module
	)
		external
		returns (bool)
	{
		if (_target != address(this) || _module != msg.sender) {
			if (!_checkMultiSig()) {
				return false;
			}
		}
		if (_target == address(this)) {
			_detachModule(_module);
		} else {
			require (tokens[_target].set);
			SecurityToken(_target).detachModule(_module);
		}
		return true;
	}

}