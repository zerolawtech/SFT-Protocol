pragma solidity >=0.4.24 <0.5.0;

import "../open-zeppelin/SafeMath.sol";
import "./bases/Checkpoint.sol";

/**
	@title Ether Dividend Payment Module
	@dev attached at token
 */
contract DividendModule is CheckpointModuleBase {

	using SafeMath for uint256;

	string public name = "Dividend";
	uint256 public dividendAmount;
	uint256 public claimExpiration;

	mapping (address => bool) claimed;
	mapping (address => mapping (address => bool)) claimedCustodian;

	event DividendIssued(uint256 time, uint256 amount);
	event DividendClaimed(address beneficiary, uint256 amount);
	event DividendExpired(uint256 unclaimedAmount);
	event CustodianDividendClaimed(
		address indexed custodian,
		address beneficiary,
		uint256 amount
	);

	/**
		@notice Base constructor
		@param _token SecurityToken contract address
		@param _issuer IssuingEntity contract address
		@param _checkpointTime Epoch time of balance checkpoint
	 */
	constructor(
		address _token,
		address _issuer,
		uint256 _checkpointTime
	)
		CheckpointModuleBase(_token, _issuer, _checkpointTime)
		public
	{
		return;
	}

	/**
		@notice Issue a dividend
		@dev
			Multisig authority check allows any number of authority addresses
			to send ETH towards the total dividend amount, until threshold is met
		@param _claimPeriod Time in seconds that dividend is claimable
	 */
	function issueDividend(uint256 _claimPeriod) external payable returns (bool) {
		require (claimExpiration == 0);
		require (now > checkpointTime);
		if (!_onlyAuthority()) return false;
		require (address(this).balance > 0);
		claimExpiration = now.add(_claimPeriod);
		dividendAmount = address(this).balance;
		totalSupply = totalSupply.sub(_getBalance(token.issuer()));
		emit DividendIssued(now, msg.value);
		return true;
	}

	/**
		@notice Trigger a dividend payment to an address
		@dev Any address may call to trigger a dividend payment to a beneficiary
		@param _beneficiary Address to send dividend to
		@return bool
	 */
	function claimDividend(address _beneficiary) external returns (bool) {
		require (dividendAmount > 0);
		_claim(_beneficiary == 0 ? msg.sender : _beneficiary);
		return true;
	}

	/**
		@notice Trigger many dividend payments at once
		@param _beneficiaries Array of addresses to send dividends to
		@return bool
	 */
	function claimMany(address[] _beneficiaries) external returns (bool) {
		require (dividendAmount > 0);
		for (uint256 i; i < _beneficiaries.length; i++) {
			_claim(_beneficiaries[i]);
		}
		return true;
	}

	/**
		@notice Internal shared payment logic
		@param _beneficiary Address to send dividend to
	 */
	function _claim(address _beneficiary) internal {
		require(issuer.isRegisteredInvestor(_beneficiary));
		require (!claimed[_beneficiary]);
		uint256 _value = _getBalance(
			_beneficiary
		).mul(dividendAmount).div(totalSupply);
		claimed[_beneficiary] = true;
		_beneficiary.transfer(_value);
		emit DividendClaimed(_beneficiary, _value);
	}

	/**
		@notice Trigger a dividend payment to an address, on a custodied balance
		@param _beneficiary Address to send dividend to
		@param _custodian Address of custodian where balance is held
		@return bool
	 */
	function claimCustodianDividend(
		address _beneficiary,
		address _custodian
	)
		external
		returns (bool)
	{
		require (dividendAmount > 0);
		_claimCustodian(_beneficiary, _custodian);
		return true;
	}

	/**
		@notice Trigger many dividend payments on custodied balances
		@param _beneficiaries Array of addresses to send dividends to
		@param _custodian Address of custodian
		@return bool
	 */
	function claimManyCustodian(
		address[] _beneficiaries,
		address _custodian
	)
		external
		returns (bool)
	{
		require (dividendAmount > 0);
		for (uint256 i; i < _beneficiaries.length; i++) {
			_claimCustodian(_beneficiaries[i], _custodian);
		}
		return true;
	}

	/**
		@notice Shared payment logic, custodied balance
		@param _beneficiary Address to send dividend to
		@param _custodian Custodian address
	 */
	function _claimCustodian(address _beneficiary, address _custodian) internal {
		require(issuer.isRegisteredInvestor(_beneficiary));
		require (!claimedCustodian[_beneficiary][_custodian]);
		uint256 _value = _getCustodianBalance(
			_beneficiary,
			_custodian
		).mul(dividendAmount).div(totalSupply);
		claimedCustodian[_beneficiary][_custodian] = true;
		_beneficiary.transfer(_value);
		emit CustodianDividendClaimed(
			_custodian,
			_beneficiary,
			_value
		);
	}

	/**
		@notice Close dividend payments
		@dev Only callable if claim period has passed or all payments were made
		@return bool
	 */
	function closeDividend() external returns (bool) {
		require (dividendAmount > 0);
		require (now > claimExpiration || address(this).balance == 0);
		if (!_onlyAuthority()) return false;
		emit DividendExpired(address(this).balance);
		msg.sender.transfer(address(this).balance);
		require (token.detachModule(address(this)));
		return true;
	}

}
