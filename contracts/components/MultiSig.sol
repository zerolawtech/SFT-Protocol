pragma solidity ^0.4.24;

import "../open-zeppelin/SafeMath.sol";

/** @title MultiSignature, MultiOwner Controls */
contract MultiSig {

	using SafeMath32 for uint32;

	struct Address {
		bytes32 id;
		bool restricted;
	}

	struct Authority {
		mapping (bytes4 => bool) signatures;
		mapping (bytes32 => address[]) multiSigAuth;
		uint32 multiSigThreshold;
		uint32 addressCount;
		uint32 approvedUntil;
	}

	bytes32 public ownerID;
	mapping (address => Address) idMap;
	mapping (bytes32 => Authority) authorityData;

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
		uint32 approvedUntil,
		uint32 threshold
	);
	event NewAuthorityAddresses (
		bytes32 indexed id,
		address[] added,
		uint32 ownerCount
	);
	event RemovedAuthorityAddresses (
		bytes32 indexed id,
		address[] removed,
		uint32 ownerCount
	);
	event ApprovedUntilSet (bytes32 indexed id, uint32 approvedUntil);
	event ThresholdSet (bytes32 indexed id, uint32 threshold);
	event NewAuthorityPermissions (bytes32 indexed id, bytes4[] signatures);
	event RemovedAuthorityPermissions (bytes32 indexed id, bytes4[] signatures);
	
	/** @dev Checks that the calling address is associated with the owner */
	modifier onlyOwner() {
		require(idMap[msg.sender].id == ownerID);
		require(!idMap[msg.sender].restricted);
		_;
	}

	/**
		@dev
	 		Checks that the calling address belongs to the owner, or is
			associated with the authority it is trying to enact a change upon.
	 */
	modifier onlySelfAuthority(bytes32 _id) {
		require (_id != 0);
		if (idMap[msg.sender].id != ownerID) {
			require(idMap[msg.sender].id == _id);
		}
		_;
	}

	/**
		@notice KYC registrar constructor
		@param _owners Array of addresses for owning authority
		@param _threshold multisig threshold for owning authority
	 */ 
	constructor(address[] _owners, uint32 _threshold) public {
		require(_owners.length >= _threshold);
		require(_owners.length > 0);
		ownerID = keccak256(abi.encodePacked(address(this)));
		Authority storage a = authorityData[ownerID];
		for (uint256 i = 0; i < _owners.length; i++) {
			require(idMap[_owners[i]].id == 0);
			idMap[_owners[i]].id = ownerID;
		}
		a.addressCount = uint32(_owners.length);
		a.multiSigThreshold = _threshold;
		emit NewAuthority(ownerID, a.approvedUntil, _threshold);
		emit NewAuthorityAddresses(ownerID, _owners, a.addressCount);
	}

	/**
		@notice Internal multisig functionality
		@dev
			Includiding a call to this function will also restrict
			the calling function so that only an authority may use it.
			It is comparble to using an 'onlyAuthority' modifier.
		@return bool - has call met multisig threshold?
	 */
	function _checkMultiSig() internal returns (bool) {
		bytes32 _id = idMap[msg.sender].id;
		require(_id != 0);
		require(!idMap[msg.sender].restricted);
		if (_id != ownerID) {
			require(authorityData[_id].signatures[msg.sig]);
			require(authorityData[_id].approvedUntil >= now);
		}
		return _multiSigPrivate(
			_id,
			msg.sig,
			keccak256(msg.data),
			msg.sender
		);
	}

	/**
		@notice External multisig functionality
		@dev
			This call allows you to add multisig functionality to modules.
			It uses tx.origin to confirm that the original caller is an
			approved authority.
		@param _sig original msg.sig
		@param _callHash keccack256 of original msg.calldata
		@return bool - has call met multisig threshold?
	 */
	function checkMultiSigExternal(
		bytes4 _sig,
		bytes32 _callHash
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

	/**
		@notice Private multisig functionality
		@dev common logic for _checkMultiSig() and checkMultiSigExternal()
		@param _id calling authority ID
		@param _sig original msg.sig
		@param _callHash keccack256 of msg.callhash
		@param _sender caller address
		@return bool - has call met multisig threshold?
	 */
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

	/**
		@notice Check if address belongs to an approved authority
		@dev Used to verify permission for calls to modules
		@param _addr Address of caller
		@param _sig Original msg.sig
		@return bool approval
	 */
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
		external
		onlyOwner
		returns (bool)
	{
		if (!_checkMultiSig()) return false;
		require (_addr.length >= _threshold);
		require (_addr.length > 0);
		bytes32 _id = keccak256(abi.encodePacked(_addr));
		Authority storage a = authorityData[_id];
		require(a.addressCount == 0);
		require(_id != 0);
		for (uint256 i = 0; i < _addr.length; i++) {
			require(idMap[_addr[i]].id == 0);
			idMap[_addr[i]].id = _id;
		}
		for (i = 0; i < _signatures.length; i++) {
			a.signatures[_signatures[i]] = true;
		}
		a.approvedUntil = _approvedUntil;
		a.addressCount = uint32(_addr.length);
		a.multiSigThreshold = _threshold;
		emit NewAuthority(_id, _threshold, _approvedUntil);
		emit NewAuthorityAddresses(_id, _addr, a.addressCount);
		emit NewAuthorityPermissions(_id, _signatures);
		return true;
	}

	/**
		@notice Modify an authority's approvedUntil time
		@dev You can restrict an authority by setting the value to 0
		@param _id Authority ID
		@param _approvedUntil Epoch time that authority is approved until
		@return bool success
	 */
	function setAuthorityApprovedUntil(
		bytes32 _id,
		uint32 _approvedUntil
	 )
	 	external
		 onlyOwner
		 returns (bool)
	{
		if (!_checkMultiSig()) return false;
		require(authorityData[_id].addressCount > 0);
		authorityData[_id].approvedUntil = _approvedUntil;
		emit ApprovedUntilSet(_id, _approvedUntil);
		return true;
	}

	/**
		@notice Modify an authority's permitted function calls
		@param _id Authority ID
		@param _signatures Array of bytes4 sigs
		@param _allowed bool permission for calling the signatures
		@return bool success
	 */
	function setAuthoritySignatures(
		bytes32 _id,
		bytes4[] _signatures,
		bool _allowed
	)
		external
		onlyOwner
		returns (bool)
	{
		if (!_checkMultiSig()) return false;
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

	/**
		@notice Modify an authority's multisig threshold
		@param _id Authority ID
		@param _threshold New multisig threshold value
		@return bool success
	 */
	function setAuthorityThreshold(
		bytes32 _id,
		uint32 _threshold
	)
		external
		onlySelfAuthority(_id)
		returns (bool)
	{
		if (!_checkMultiSig()) return false;
		Authority storage a = authorityData[idMap[msg.sender].id];
		require(a.addressCount >= _threshold);
		a.multiSigThreshold = _threshold;
		emit ThresholdSet(_id, _threshold);
		return true;
	}

	/**
		@notice Add new addresses to an authority
		@param _id Authority ID
		@param _addr Array of addresses
		@return bool success
	 */
	function addAuthorityAddresses(
		bytes32 _id,
		address[] _addr
	)
		external
		onlySelfAuthority(_id)
		returns (bool)
	{
		if (!_checkMultiSig()) return false;
		Authority storage a = authorityData[_id];
		require(a.addressCount > 0);
		for (uint256 i = 0; i < _addr.length; i++) {
			require(idMap[_addr[i]].id == 0);
			idMap[_addr[i]].id = _id;
		}
		a.addressCount = a.addressCount.add(uint32(_addr.length));
		emit NewAuthorityAddresses(_id, _addr, a.addressCount);
		return true;
	}

	/**
		@notice Remove addresses from an authority
		@dev Once an address has been removed it may never be re-used
		@param _id Authority ID
		@param _addr Array of addresses
		@return bool success
	 */
	function removeAuthorityAddresses(
		bytes32 _id,
		address[] _addr
	)
		external
		onlySelfAuthority(_id)
		returns (bool)
	{
		if (!_checkMultiSig()) return false;
		Authority storage a = authorityData[_id];
		for (uint256 i = 0; i < _addr.length; i++) {
			require(idMap[_addr[i]].id == _id);
			require(!idMap[_addr[i]].restricted);
			idMap[_addr[i]].restricted = true;
		}
		a.addressCount = a.addressCount.sub(uint32(_addr.length));
		require (a.addressCount >= a.multiSigThreshold);
		require (a.addressCount > 0);
		emit RemovedAuthorityAddresses(_id, _addr, a.addressCount);
		return true;
	}

}
