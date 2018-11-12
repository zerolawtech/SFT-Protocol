pragma solidity ^0.4.24;

import "./open-zeppelin/SafeMath.sol";

/// @title MultiSignature Owner Controls
contract MultiSig {

	using SafeMath64 for uint64;

	bytes32 ownerID;
	mapping (address => Address) idMap;
	mapping (bytes32 => Authority) authorityData;

	struct Address {
		bytes32 id;
		bool restricted;
	}

	struct Authority {
		mapping (bytes4 => bool) permitted;
		mapping (bytes32 => address[]) multiSigAuth;
		uint64 multiSigThreshold;
		uint64 addressCount;
		bool approved;
	}

	event MultiSigCall (
		bytes32 indexed id,
		bytes4 indexed callSignature,
		bytes32 indexed callHash,
		address caller,
		uint256 callCount
	);
	event MultiSigCallApproved (
		bytes32 indexed id,
		bytes4 indexed callSignature,
		bytes32 indexed callHash,
		address caller
	);
	event ThresholdSet (bytes32 indexed id, uint64 threshold);
	event NewOwners (bytes32 indexed id, address[] added, uint64 ownerCount);
	event RemovedOwners (bytes32 indexed id, address[] removed, uint64 ownerCount);

	modifier onlyOwner() {
		require(idMap[msg.sender].id == ownerID);
		_;
	}

	constructor(address[] _owners, uint64 _threshold) public {
		require(_owners.length >= _threshold);
		require(_threshold > 0);
		ownerID = keccak256(abi.encodePacked(address(this)));
		for (uint256 i = 0; i < _owners.length; i++) {
			idMap[_owners[i]].id = ownerID;
		}
		authorityData[ownerID].addressCount = uint64(_owners.length);
		authorityData[ownerID].multiSigThreshold = _threshold;
		authorityData[ownerID].approved = true;
		emit NewOwners(ownerID, _owners, authorityData[ownerID].addressCount);
		emit ThresholdSet(ownerID, _threshold);
	}

	function _checkMultiSig() internal returns (bool) {
		bytes32 _callHash = keccak256(msg.data);
		bytes32 _id = idMap[msg.sender].id;
		Authority storage a = authorityData[_id];
		if (_id != ownerID) {
			require(a.permitted[msg.sig]);
		} 
		for (uint256 i = 0; i < a.multiSigAuth[_callHash].length; i++) {
			require(a.multiSigAuth[_callHash][i] != msg.sender);
		}
		if (a.multiSigAuth[_callHash].length + 1 >= a.multiSigThreshold) {
			delete a.multiSigAuth[_callHash];
			emit MultiSigCallApproved(_id, msg.sig, _callHash, msg.sender);
			return true;
		}
		a.multiSigAuth[_callHash].push(msg.sender);
		emit MultiSigCall(
			_id, 
			msg.sig,
			_callHash,
			msg.sender,
			a.multiSigAuth[_callHash].length
		);
		return false;
	}

	function setMultiSigThreshold(uint64 _threshold) external onlyOwner returns (bool) {
		if (!_checkMultiSig()) {
			return false;
		}
		Authority storage a = authorityData[idMap[msg.sender].id];
		require(a.addressCount >= _threshold);
		require(_threshold > 0);
		a.multiSigThreshold = _threshold;
		return true;
	}

	function addOwners(bytes32 _id, address[] _owners) external onlyOwner returns (bool) {
		require(_id != 0);
		if (!_checkMultiSig()) {
			return false;
		}
		bytes32 _authID = idMap[msg.sender].id;
		Authority storage a = authorityData[_id];
		/* only original owner may add addresses to another sub-authority */
		require (_authID == _id || _authID == ownerID);
		require (a.approved);
		for (uint256 i = 0; i < _owners.length; i++) {
			require(idMap[_owners[i]].id == 0);
			idMap[_owners[i]].id = _id;
		}
		a.addressCount = a.addressCount.add(uint64(_owners.length));
		emit NewOwners(_id, _owners, a.addressCount);
		return true;
	}

	function removeOwners(bytes32 _id, address[] _owners) external onlyOwner returns (bool) {
		require(_id != 0);
		if (!_checkMultiSig()) {
			return false;
		}
		bytes32 _authID = idMap[msg.sender].id;
		Authority storage a = authorityData[_id];
		/* only original owner may remove addresses from another sub-authority */
		require (_authID == _id || _authID == ownerID);
		require (a.approved);
		require(a.addressCount.sub(uint64(_owners.length)) >= a.multiSigThreshold);
		for (uint256 i = 0; i < _owners.length; i++) {
			require(idMap[_owners[i]].id == _id);
			require(!idMap[_owners[i]].restricted);
			idMap[_owners[i]].restricted = true;
		}
		a.addressCount = a.addressCount.sub(uint64(_owners.length));
		emit RemovedOwners(_id, _owners, a.addressCount);
		return true;
	}


}
