pragma solidity ^0.4.24;

import "./open-zeppelin/SafeMath.sol";
import "./SecurityToken.sol";
import "./components/MultiSig.sol";

/**
	@title Custodian Contract
	@dev
		This is a bare-bones implementation of a custodian contract,
		it should be expanded upon depending on the specific needs
		of the owner.
 */
contract Custodian is MultiSigMultiOwner {

	using SafeMath64 for uint64;

	string public name;
	bytes32 public id;
	mapping (address => bool) public addresses;

	mapping (address => Issuer) issuers;
	mapping (address => address) issuerContracts;

	struct Issuer {
		uint64[8] counts;
		mapping (uint16 => uint64[8]) countries;
		mapping(bytes32 => address[]) investors;
	}


	/**
		@notice Custodian constructor
		@param _name Human-readable name of custodian
		@param _owners Array of addresses to associate with owner
		@param _threshold multisig threshold for owning authority
	 */
	constructor(
		string _name,
		address[] _owners,
		uint64 _threshold
	)
		MultiSigMultiOwner(_owners, _threshold)
		public
	{
		name = _name;
		id = keccak256(abi.encodePacked(address(this)));
	}

	/**
		@notice Custodian transfer function
		@dev
			Addresses associated to the custodian cannot directly hold tokens,
			so they must use this transfer function to move them.
		@param _token Address of the token to transfer
		@param _to Address of the recipient
		@param _value Amount to transfer
		@return bool success
	 */
	function transfer(
		address _token,
		address _to,
		uint256 _value,
		bool _remove
	)
		external
		returns (bool)
	{
		if (!_checkMultiSig()) return false;
		SecurityToken t = SecurityToken(_token);
		require(t.transfer(_to, _value));
		if (_remove) {
			IssuingEntity i = IssuingEntity(issuerContracts[_to]);
			_removeInvestor(_token, i.getID(_to));
		}
		return true;
	}

	function newInvestor(address _token, bytes32 _id, uint8 _rating, uint16 _country) external returns (bool) {
		if (address(issuerContracts[_token]) == 0) {
			require(SecurityToken(_token).issuer() == msg.sender);
			issuerContracts[_token] = msg.sender;
		} else {
			require(issuerContracts[_token] == msg.sender);
		}

		Issuer storage _issuer = issuers[msg.sender];
		for (uint256 i = 0; i < _issuer.investors[_id].length; i++) {
			if (_issuer.investors[_id][i] == _token) return false;
		}
		_issuer.investors[_id].push(_token);
		_issuer.counts[0] = _issuer.counts[0].add(1);
		_issuer.counts[_rating] = _issuer.counts[_rating].add(1);
		_issuer.countries[_country][0] = _issuer.countries[_country][0].add(1);
		_issuer.countries[_country][_rating] = _issuer.countries[_country][_rating].add(1);
		return true;
	}

	function removeInvestors(address[] _token, bytes32[] _id) external returns (bool) {
		require (_token.length == _id.length);
		for (uint256 i = 0; i < _token.length; i++) {
			_removeInvestor(_token[i], _id[i]);
		}
		return true;
	}

	function _removeInvestor(address _token, bytes32 _id) internal {
		Issuer storage _issuer = issuers[issuerContracts[_token]];
		address[] storage _inv = _issuer.investors[_id];
		for (uint256 i = 0; i < _inv.length; i++) {
			if (_inv[i] == _token) {
				_inv[i] = _inv[_inv.length-1];
				_inv.length -= 1;
				if (_inv.length > 0) return;
				(uint8 _rating, uint16 _country) = IssuingEntity(issuerContracts[_token]).removeCustodianInvestor(_id);
				_issuer.counts[0] = _issuer.counts[0].sub(1);
				_issuer.counts[_rating] = _issuer.counts[_rating].sub(1);
				_issuer.countries[_country][0] = _issuer.countries[_country][0].sub(1);
				_issuer.countries[_country][_rating] = _issuer.countries[_country][_rating].sub(1);
				return;
			}
		}
	}


	function _increaseCount(address _addr, uint8 _rating, uint16 _country) internal {
		Issuer storage _issuer = issuers[_addr];
		_issuer.counts[0] = _issuer.counts[0].add(1);
		_issuer.counts[_rating] = _issuer.counts[_rating].add(1);
		_issuer.countries[_country][0] = _issuer.countries[_country][0].add(1);
		_issuer.countries[_country][_rating] = _issuer.countries[_country][_rating].add(1);
		
	}

	function _decreaseCount(address _addr, uint8 _rating, uint16 _country) internal {
		Issuer storage _issuer = issuers[_addr];
		_issuer.counts[0] = _issuer.counts[0].sub(1);
		_issuer.counts[_rating] = _issuer.counts[_rating].sub(1);
		_issuer.countries[_country][0] = _issuer.countries[_country][0].sub(1);
		_issuer.countries[_country][_rating] = _issuer.countries[_country][_rating].sub(1);
		
	}

}
