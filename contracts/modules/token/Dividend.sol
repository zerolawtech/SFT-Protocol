pragma solidity >=0.4.24 <0.5.0;

import "../../open-zeppelin/SafeMath.sol";
import "./BaseCheckpoint.sol";

contract DividendModule is CheckpointModule {

	using SafeMath for uint256;

	string public name = "Dividend";
	uint256 public dividendTime;
	uint256 public dividendAmount;
	uint256 public claimExpiration;

	mapping (address => bool) claimed;
	mapping (address => mapping (bytes32 => bool)) claimedCustodian;

	event DividendIssued(uint256 time, uint256 amount);
	event DividendClaimed(address beneficiary, uint256 amount);
	event DividendExpired(uint256 unclaimedAmount);
	event CustodianDividendClaimed(
		address indexed custodian,
		bytes32 beneficiaryID,
		address beneficiary,
		uint256 amount
	);

	constructor(
		address _token,
		address _issuer,
		uint256 _time
	)
		CheckpointModule(_token, _issuer, _time)
		public
	{

	}

	function issueDividend(uint256 _claimPeriod) external onlyAuthority payable {
		require (dividendTime < now);
		require (claimExpiration == 0);
		require (msg.value > 0);
		claimExpiration = now.add(_claimPeriod);
		dividendAmount = msg.value;
		totalSupply = totalSupply.sub(_getBalance(token.issuer()));
		emit DividendIssued(dividendTime, msg.value);
	}

	function claimDividend(address _beneficiary) public {
		require (address(this).balance > 0);
		if (_beneficiary == 0) {
			_beneficiary = msg.sender;
		}
		require (issuer.getID(_beneficiary) != ownerID);
		require (!claimed[_beneficiary]);
		uint256 _value = (
			_getBalance(_beneficiary).mul(dividendAmount).div(totalSupply)
		);
		claimed[_beneficiary] = true;
		_beneficiary.transfer(_value);
		emit DividendClaimed(_beneficiary, _value);
	}

	function claimMany(address[] _beneficiaries) public {
		for (uint256 i = 0; i < _beneficiaries.length; i++) {
			claimDividend(_beneficiaries[i]);
		}
	}

	function claimCustodianDividend(
		address _custodian,
		bytes32 _beneficiaryID,
		address _beneficiary
	)
		public
	{
		require (address(this).balance > 0);
		if (_beneficiaryID == 0) {
			_beneficiaryID = issuer.getID(msg.sender);
		}
		if (_beneficiary == 0) {
			_beneficiary = msg.sender;
		}
		require (_beneficiaryID != ownerID);
		require (!claimedCustodian[_custodian][_beneficiaryID]);
		require (issuer.getID(_beneficiary) == _beneficiaryID);
		uint256 _value = _getCustodianBalance(
			_custodian,
			_beneficiaryID
		).mul(dividendAmount).div(totalSupply);
		claimedCustodian[_custodian][_beneficiaryID] = true;
		msg.sender.transfer(_value);
		emit CustodianDividendClaimed(
			_custodian,
			_beneficiaryID,
			_beneficiary,
			_value
		);
	}

	function closeDividend() external onlyAuthority {
		require (claimExpiration > 0);
		require (now > claimExpiration || address(this).balance == 0);
		emit DividendExpired(address(this).balance);
		msg.sender.transfer(address(this).balance);
		require (token.detachModule(address(this)));
	}

}
