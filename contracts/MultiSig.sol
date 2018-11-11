pragma solidity ^0.4.24;

import "./open-zeppelin/SafeMath.sol";

/// @title MultiSignature Owner Controls
contract MultiSig {

	using SafeMath64 for uint64;

	mapping (address => bool) public owners;
	mapping (bytes32 => address[]) multiSigAuth;
	uint64 public multiSigThreshold;
	uint64 public ownerCount;

	event MultiSigCall (
		address indexed caller,
		bytes4 indexed callSignature,
		bytes32 indexed callHash,
		uint256 callCount
	);
	event MultiSigCallApproved (
		address indexed caller,
		bytes4 indexed callSignature,
		bytes32 indexed callHash
	);
	event ThresholdSet (uint64 threshold);
	event NewOwners (address[] added, uint64 ownerCount);
	event RemovedOwners (address[] removed, uint64 ownerCount);

	modifier onlyOwner() {
		require(owners[msg.sender]);
		_;
	}

	constructor(address[] _owners, uint64 _threshold) public {
		require(_owners.length >= _threshold);
		require(_threshold > 0);
		for (uint256 i = 0; i < _owners.length; i++) {
			owners[_owners[i]] = true;
		}
		ownerCount = uint64(_owners.length);
		multiSigThreshold = _threshold;
		emit NewOwners(_owners, ownerCount);
		emit ThresholdSet(_threshold);
	}

	function _checkMultiSig() internal returns (bool) {
		bytes32 _callHash = keccak256(msg.data);
		for (uint256 i = 0; i < multiSigAuth[_callHash].length; i++) {
			require(multiSigAuth[_callHash][i] != msg.sender);
		}
		if (multiSigAuth[_callHash].length + 1 >= multiSigThreshold) {
			delete multiSigAuth[_callHash];
			emit MultiSigCallApproved(msg.sender, msg.sig, _callHash);
			return true;
		}
		multiSigAuth[_callHash].push(msg.sender);
		emit MultiSigCall(
			msg.sender,
			msg.sig,
			_callHash,
			multiSigAuth[_callHash].length
		);
		return false;
	}

	function setMultiSigThreshold(uint64 _threshold) external onlyOwner returns (bool) {
		if (!_checkMultiSig()) {
			return false;
		}
		require(ownerCount >= _threshold);
		require(_threshold > 0);
		multiSigThreshold = _threshold;
		return true;
	}

	function addOwners(address[] _owners) external onlyOwner returns (bool) {
		if (!_checkMultiSig()) {
			return false;
		}
		for (uint256 i = 0; i < _owners.length; i++) {
			require(!owners[_owners[i]]);
			owners[_owners[i]] = true;
		}
		ownerCount = ownerCount.add(uint64(_owners.length));
		emit NewOwners(_owners, ownerCount);
		return true;
	}

	function removeOwners(address[] _owners) external onlyOwner returns (bool) {
		if (!_checkMultiSig()) {
			return false;
		}
		require(ownerCount.sub(uint64(_owners.length)) >= multiSigThreshold);
		for (uint256 i = 0; i < _owners.length; i++) {
			require(!owners[_owners[i]]);
			delete owners[_owners[i]];
		}
		ownerCount = ownerCount.add(uint64(_owners.length));
		emit RemovedOwners(_owners, ownerCount);
		return true;
	}


}
