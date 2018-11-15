pragma solidity ^0.4.24;

import "./open-zeppelin/SafeMath.sol";

/// @title MultiSignature, MultiOwner Controls
contract MultiSigMultiOwner {

	using SafeMath64 for uint64;

	bytes32 public ownerID;
	mapping (address => Address) idMap;
	mapping (bytes32 => Authority) authorityData;

	struct Address {
		bytes32 id;
		bool restricted;
	}

	struct Authority {
		mapping (bytes4 => bool) signatures;
		mapping (bytes32 => address[]) multiSigAuth;
		uint64 multiSigThreshold;
		uint64 addressCount;
		uint64 approvedUntil;
	}

	event MultiSigCall (
		bytes32 indexed id,
		bytes4 indexed callSignature,
		bytes32 indexed callHash,
		address caller,
		uint256 callCount,
		uint256 threshold
	);
	event MultiSigCallApproved (
		bytes32 indexed id,
		bytes4 indexed callSignature,
		bytes32 indexed callHash,
		address caller
	);
	event NewAuthority (
		bytes32 indexed id,
		uint64 approvedUntil,
		uint64 threshold
	);
	event ApprovedUntilSet (bytes32 indexed id, uint64 approvedUntil);
	event ThresholdSet (bytes32 indexed id, uint64 threshold);
	event NewAuthorityPermissions (bytes32 indexed id, bytes4[] signatures);
	event RemovedAuthorityPermissions (bytes32 indexed id, bytes4[] signatures);
	event NewAuthorityAddresses (
		bytes32 indexed id,
		address[] added,
		uint64 ownerCount
	);
	event RemovedAuthorityAddresses (
		bytes32 indexed id,
		address[] removed,
		uint64 ownerCount
	);

	modifier onlyOwner() {
		require(idMap[msg.sender].id == ownerID);
		require(!idMap[msg.sender].restricted);
		_;
	}

	modifier onlyAuthority() {
		bytes32 _id = idMap[msg.sender].id;
		require(_id != 0);
		require(!idMap[msg.sender].restricted);
		if (_id != ownerID) {
			require(authorityData[_id].signatures[msg.sig]);
			require(authorityData[_id].approvedUntil >= now);
		}
		_;
	}

	modifier onlySelfAuthority(bytes32 _id) {
		require (_id != 0);
		if (idMap[msg.sender].id != ownerID) {
			require(idMap[msg.sender].id == _id);
		}
		_;
	}

	constructor(address[] _owners, uint64 _threshold) public {
		require(_owners.length >= _threshold);
		require(_owners.length > 0);
		ownerID = keccak256(abi.encodePacked(address(this)));
		Authority storage a = authorityData[ownerID];
		for (uint256 i = 0; i < _owners.length; i++) {
			idMap[_owners[i]].id = ownerID;
		}
		a.addressCount = uint64(_owners.length);
		a.multiSigThreshold = _threshold;
		emit NewAuthority(ownerID, a.approvedUntil, _threshold);
		emit NewAuthorityAddresses(ownerID, _owners, a.addressCount);
	}

	function _checkMultiSig() internal onlyAuthority returns (bool) {
		return _multiSigPrivate(
			idMap[msg.sender].id,
			msg.sig,
			keccak256(msg.data),
			msg.sender
		);
	}

	function checkMultiSigExternal(
		bytes32 _callHash,
		bytes4 _sig
	)
		external
		returns (bool)
	{
		bytes32 _id = idMap[tx.origin].id;
		require(_id != 0);
		require(!idMap[tx.origin].restricted);
		if (_id != ownerID) {
			require(authorityData[_id].signatures[_sig]);
			require(authorityData[_id].approvedUntil >= now);
		}
		return _multiSigPrivate(
			_id,
			_sig,
			keccak256(abi.encodePacked(_callHash, _sig, msg.sender)),
			tx.origin
		);
	}

	function isApprovedAuthority(
		address _addr,
		bytes4 _sig
	)
		external
		view
		returns (bool)
	{
		bytes32 _id = idMap[_addr].id;
		require(_id != 0);
		require(!idMap[_addr].restricted);
		if (_id != ownerID) {
			require(authorityData[_id].signatures[_sig]);
			require(authorityData[_id].approvedUntil >= now);
		}
		return true;
	}

	function _multiSigPrivate(
		bytes32 _id,
		bytes4 _sig,
		bytes32 _callHash,
		address _sender
	)
		private
		returns (bool)
	{
		Authority storage a = authorityData[_id];
		for (uint256 i = 0; i < a.multiSigAuth[_callHash].length; i++) {
			require(a.multiSigAuth[_callHash][i] != _sender);
		}
		if (a.multiSigAuth[_callHash].length + 1 >= a.multiSigThreshold) {
			delete a.multiSigAuth[_callHash];
			emit MultiSigCallApproved(_id, _sig, _callHash, _sender);
			return true;
		}
		a.multiSigAuth[_callHash].push(_sender);
		emit MultiSigCall(
			_id, 
			_sig,
			_callHash,
			_sender,
			a.multiSigAuth[_callHash].length,
			a.multiSigThreshold
		);
		return false;

	}

	function addAuthority(
		bytes32 _id,
		address[] _owners,
		bytes4[] _signatures,
		uint64 _approvedUntil,
		uint64 _threshold
	)
		external
		onlyOwner
		returns (bool)
	{
		if (!_checkMultiSig()) {
			return false;
		}
		require (_owners.length >= _threshold);
		require (_owners.length > 0);
		Authority storage a = authorityData[_id];
		require(a.addressCount == 0);
		require(_id != 0);
		for (uint256 i = 0; i < _owners.length; i++) {
			require(idMap[_owners[i]].id == 0);
			idMap[_owners[i]].id = _id;
		}
		for (i = 0; i < _signatures.length; i++) {
			a.signatures[_signatures[i]] = true;
		}
		a.approvedUntil = _approvedUntil;
		a.addressCount = uint64(_owners.length);
		a.multiSigThreshold = _threshold;
		emit NewAuthority(_id, _threshold, _approvedUntil);
		emit NewAuthorityAddresses(_id, _owners, a.addressCount);
		emit NewAuthorityPermissions(_id, _signatures);
		return true;
	}

	function setAuthorityApprovedUntil(
		bytes32 _id,
		uint64 _approvedUntil
	 )
	 	external
		 onlyOwner
		 returns (bool)
	{
		if (!_checkMultiSig()) {
			return false;
		}
		require(authorityData[_id].addressCount > 0);
		authorityData[_id].approvedUntil = _approvedUntil;
		emit ApprovedUntilSet(_id, _approvedUntil);
		return true;
	}

	function setAuthoritySignatures(
		bytes32 _id,
		bytes4[] _signatures,
		bool _allowed
	)
		external
		onlyOwner
		returns (bool)
	{
		if (!_checkMultiSig()) {
			return false;
		}
		Authority storage a = authorityData[_id];
		require(a.addressCount > 0);
		for (uint256 i = 0; i < _signatures.length; i++) {
			a.signatures[_signatures[i]] = _allowed;
		}
		if (_allowed) {
			emit NewAuthorityPermissions(_id, _signatures);
		} else {
			emit RemovedAuthorityPermissions(_id, _signatures);
		}
		return true;
	}

	function setAuthorityThreshold(
		bytes32 _id,
		uint64 _threshold
	)
		external
		onlySelfAuthority(_id)
		returns (bool)
	{
		if (!_checkMultiSig()) {
			return false;
		}
		Authority storage a = authorityData[idMap[msg.sender].id];
		require(a.addressCount >= _threshold);
		a.multiSigThreshold = _threshold;
		emit ThresholdSet(_id, _threshold);
		return true;
	}

	function addAuthorityAddresses(
		bytes32 _id,
		address[] _owners
	)
		external
		onlySelfAuthority(_id)
		returns (bool)
	{
		if (!_checkMultiSig()) {
			return false;
		}
		Authority storage a = authorityData[_id];
		require(a.addressCount > 0);
		for (uint256 i = 0; i < _owners.length; i++) {
			require(idMap[_owners[i]].id == 0);
			idMap[_owners[i]].id = _id;
		}
		a.addressCount = a.addressCount.add(uint64(_owners.length));
		emit NewAuthorityAddresses(_id, _owners, a.addressCount);
		return true;
	}

	function removeAuthorityAddresses(
		bytes32 _id,
		address[] _owners
	)
		external
		onlySelfAuthority(_id)
		returns (bool)
	{
		if (!_checkMultiSig()) {
			return false;
		}
		Authority storage a = authorityData[_id];
		for (uint256 i = 0; i < _owners.length; i++) {
			require(idMap[_owners[i]].id == _id);
			require(!idMap[_owners[i]].restricted);
			idMap[_owners[i]].restricted = true;
		}
		a.addressCount = a.addressCount.sub(uint64(_owners.length));
		require (a.addressCount >= a.multiSigThreshold);
		require (a.addressCount > 0);
		emit RemovedAuthorityAddresses(_id, _owners, a.addressCount);
		return true;
	}

}
