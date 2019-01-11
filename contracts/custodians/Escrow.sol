pragma solidity >=0.4.24 <0.5.0;

import "../open-zeppelin/SafeMath.sol";
import "../SecurityToken.sol";

/** @title Custodial Escrow Contract */
contract EscrowCustodian {

	using SafeMath32 for uint32;
	using SafeMath for uint256;

	bytes32 public ownerID;
	bool accept;
	LoanAgreement[] loans;

	/* token contract => issuer contract */
	mapping (address => IssuingEntity) issuerMap;
	mapping (bytes32 => Investor) investors;

	struct Issuer {
		uint32 tokenCount;
		bool isOwner;
	}
	
	struct Investor {
		mapping (address => Issuer) issuers;
		mapping (address => uint256) balances;
	}

	struct LoanAgreement {
		bytes32 receiver;
		address lender;
		SecurityToken token;
		uint256 etherRepaid;
		uint256 tokensRepaid;
		uint256 tokenTotal;
		uint256[] paymentDates;
		uint256[] amountDue;
		uint256[] tokensReleased;
		TransferOffer transferOffer;
	}

	struct TransferOffer {
		uint256 offerAmount;
		address counterparty;
	}

	event ReceivedTokens(
		address indexed issuer,
		address indexed token,
		bytes32 indexed investorID,
		uint256 amount
	);
	event SentTokens(
		address indexed issuer,
		address indexed token,
		address indexed recipient,
		uint256 amount
	);
	event TransferOwnership(
		address indexed token,
		bytes32 indexed from,
		bytes32 indexed to,
		uint256 value
	);
	event NewLoanOffer(
		uint256 indexed loanId,
		bytes32 indexed receiver,
		address indexed lender,
		address token,
		uint256[] paymentDates,
		uint256[] amountDue,
		uint256[] tokensReleased
	);
	event LoanOfferRevoked(uint256 indexed loanId);
	event LoanOfferClaimed(uint256 indexed loanId);
	event LoanPayment(uint256 indexed loanId, uint256 amount);
	event LoanRepaid(uint256 indexed loanId);
	event LoanDefaulted(uint256 indexed loanId, uint256 amount);
	event LoanTransferOffered(
		uint256 indexed loanId,
		address counterparty,
		uint256 amount
	);
	event LoanTransferRevoked(
		uint256 indexed _loanId,
		address counterparty,
		uint256 amount
	);
	event LoanTransferClaimed(
		uint256 indexed _loanId,
		address counterparty,
		uint256 amount
	);

	/**
		@notice Custodian constructor
	 */
	constructor () public {
		ownerID = keccak256(abi.encodePacked(address(this)));
	}

	/**
		@notice Fetch an investor's current token balance held by the custodian
		@param _token address of the SecurityToken contract
		@param _id investor ID
		@return integer
	 */
	function balanceOf(
		address _token,
		bytes32 _id
	)
		external
		view
		returns (uint256)
	{
		return investors[_id].balances[_token];
	}

	/**
		@notice Check if an investor is a beneficial owner for an issuer
		@param _issuer address of the IssuingEntity contract
		@param _id investor ID
		@return bool
	 */
	function isBeneficialOwner(
		address _issuer,
		bytes32 _id
	)
		external
		view
		returns (bool)
	{
		return investors[_id].issuers[_issuer].isOwner;
	}

	/**
		@notice Internal transfer function
		@param _token Address of the token to transfer
		@param _to Address of the recipient
		@param _id ID of the recipient
		@param _value Amount to transfer
		@return bool success
	 */
	function _transfer(
		SecurityToken _token,
		address _to,
		bytes32 _id,
		uint256 _value
	)
		internal
	{
		Investor storage i = investors[_id];
		i.balances[_token] = i.balances[_token].sub(_value);
		require(_token.transfer(_to, _value));
		if (i.balances[_token] == 0) {
			Issuer storage issuer = i.issuers[issuerMap[_token]];
			issuer.tokenCount = issuer.tokenCount.sub(1);
			if (issuer.tokenCount == 0) {
				issuer.isOwner = false;
				issuerMap[_token].releaseOwnership(ownerID, _id);
			}
		}
		emit SentTokens(issuerMap[_token], _token, _to, _value);
	}

	/**
		@notice Add a new token owner
		@dev called by IssuingEntity when tokens are transferred to a custodian
		@param _token Token address
		@param _id Investor ID
		@param _value Amount transferred
		@return bool success
	 */
	function receiveTransfer(
		address _token,
		bytes32 _id,
		uint256 _value
	)
		external
		returns (bool)
	{
		/* can only receive tokens as part of claimOffer */
		require(accept);
		if (issuerMap[_token] == address(0)) {
			require(SecurityToken(_token).issuer() == msg.sender);
			issuerMap[_token] = IssuingEntity(msg.sender);
		} else {
			require(issuerMap[_token] == msg.sender);
		}
		emit ReceivedTokens(msg.sender, _token, _id, _value);
		Investor storage i = investors[_id];
		if (i.balances[_token] == 0) {
			Issuer storage issuer = i.issuers[msg.sender];
			issuer.tokenCount = issuer.tokenCount.add(1);
			if (!issuer.isOwner) {
				issuer.isOwner = true;
			}
		}
		i.balances[_token] = i.balances[_token].add(_value);
		return true;
	}

	/**
		@notice Internal transfer token ownership within the custodian
		@param _token Address of the token to transfer
		@param _fromID Sender investor ID
		@param _toID Recipient investor ID
		@param _value Amount of tokens to transfer
	 */
	function _transferInternal(
		SecurityToken _token,
		bytes32 _fromID,
		bytes32 _toID,
		uint256 _value
	)
		internal
	{
		Investor storage from = investors[_fromID];
		require(from.balances[_token] >= _value, "Insufficient balance");
		Investor storage to = investors[_toID];
		from.balances[_token] = from.balances[_token].sub(_value);
		to.balances[_token] = to.balances[_token].add(_value);
		if (to.balances[_token] == _value) {
			Issuer storage issuer = to.issuers[issuerMap[_token]];
			issuer.tokenCount = issuer.tokenCount.add(1);
			if (!issuer.isOwner) {
				issuer.isOwner = true;
			}
		}
		issuer = from.issuers[issuerMap[_token]];
		if (from.balances[_token] == 0) {
			issuer.tokenCount = issuer.tokenCount.sub(1);
			if (issuer.tokenCount == 0) {
				issuer.isOwner = false;
			}
		}
		require(_token.transferCustodian(
			[_fromID, _toID],
			_value,
			issuer.isOwner
		));
		emit TransferOwnership(_token, _fromID, _toID, _value);
	}

	/**
		@notice Make an offer of a loan
		@dev
			* Amount of the loan is msg.value
			* Required collateral amount for the loan is _tokensReleased[-1]
			* Required repayment for the loan is _amountDue[-1]
		@dev
				_amountDue and _tokensReleased represent milestones, not the
				amounts due or released at each step, so that the final array
				entry is the total amount paid or released
		@param _receiver ID of loan recipient
		@param _token Address of token to require as collateral
		@param _paymentDates Array of payment dates in epoch time
		@param _amountDue Array of total required payment amounts in wei
		@param _tokensReleased Array of total tokens released at each payment
		@return bool success
	 */
	function offerLoan(
		bytes32 _receiver,
		SecurityToken _token,
		uint256[] _paymentDates,
		uint256[] _amountDue,
		uint256[] _tokensReleased
	)
		external
		payable
		returns (bool)
	{
		require(_paymentDates.length == _amountDue.length);
		require(_paymentDates.length == _tokensReleased.length);
		require(_paymentDates[0] > now);
		require(msg.value > 0);
		for (uint256 i = 1; i < _paymentDates.length; i++) {
			require(_paymentDates[i] > _paymentDates[i-1]);
			require(_amountDue[i] > _amountDue[i-1]);
			require(_tokensReleased[i] >= _tokensReleased[i-1]);
		}
		if (issuerMap[_token] == address(0)) {
			issuerMap[_token] = _token.issuer();
		}
		loans.push(LoanAgreement(
			_receiver,
			msg.sender,
			_token,
			msg.value,
			0,
			0,
			_paymentDates,
			_amountDue,
			_tokensReleased,
			TransferOffer(0, 0)
		));
		emit NewLoanOffer(
			loans.length - 1,
			_receiver,
			msg.sender,
			_token,
			_paymentDates,
			_amountDue,
			_tokensReleased
		);
		return true;
	}

	/**
		@notice Revoke a loan offer
		@param _loanId ID of loan agreement
		@return bool success
	 */
	function revokeOffer(uint256 _loanId) external returns (bool) {
		LoanAgreement storage _offer = loans[_loanId];
		require(msg.sender == _offer.lender);
		require(_offer.tokenTotal == 0);
		msg.sender.transfer(_offer.etherRepaid);
		delete loans[_loanId];
		emit LoanOfferRevoked(_loanId);
		return true;
	}

	/**
		@notice Claim a loan offer
		@param _loanId ID of loan agreement
		@return bool success
	 */
	function claimOffer(uint256 _loanId) external returns (bool) {
		LoanAgreement storage _offer = loans[_loanId];
		require(issuerMap[_offer.token].getID(msg.sender) == _offer.receiver);
		require(_offer.paymentDates[0] > now);
		require(_offer.tokenTotal == 0);
		_offer.tokenTotal = _offer.tokensReleased[_offer.tokensReleased.length-1];
		accept = true;
		require(_offer.token.transferFrom(
			msg.sender,
			address(this),
			_offer.tokenTotal
		));
		accept = false;
		msg.sender.transfer(_offer.etherRepaid);
		_offer.etherRepaid = 0;
		emit LoanOfferClaimed(_loanId);
		return true;
	}

	/**
		@notice Make a payment on an active loan
		@param _loanId ID of loan agreement
		@return bool success
	 */
	function makePayment(uint256 _loanId) external payable returns (bool) {
		LoanAgreement storage _offer = loans[_loanId];
		bytes32 _id = issuerMap[_offer.token].getID(msg.sender);
		require(_id == _offer.receiver);
		require(_offer.tokenTotal > _offer.tokensRepaid);
		_offer.etherRepaid = _offer.etherRepaid.add(msg.value);
		_offer.lender.transfer(msg.value);
		emit LoanPayment(_loanId, msg.value);
		for (uint256 i = _offer.paymentDates.length-1; i+1 != 0; i--) {
			if (
				_offer.amountDue[i] <= _offer.etherRepaid &&
				_offer.tokensReleased[i] > _offer.tokensRepaid
			) {
				uint256 _amount = _offer.tokensReleased[i].sub(_offer.tokensRepaid);
				_offer.tokensRepaid = _offer.tokensReleased[i];
				_transfer(_offer.token, msg.sender, _id, _amount);
				if (_offer.tokensRepaid == _offer.tokenTotal) {
					emit LoanRepaid(_loanId);
					delete loans[_loanId];
				}
				return true;
			}
		}
		return true;
	}

	/**
		@notice Claim escrowed tokens on a defaulted loan
		@dev
			In order to successfully take ownership of the tokens, the lender
			will need to be KYC'd by an associated registry
		@param _loanId ID of loan agreement
		@return bool success
	 */
	function claimCollateral(uint256 _loanId) external returns (bool) {
		LoanAgreement storage _offer = loans[_loanId];
		require(msg.sender == _offer.lender);
		for (uint256 i = 0; i < _offer.paymentDates.length; i++) {
			require(_offer.paymentDates[i] < now);
			if (_offer.amountDue[i] > _offer.etherRepaid) {
				bytes32 _id = issuerMap[_offer.token].getID(msg.sender);
				uint256 _amount = _offer.tokenTotal.sub(_offer.tokensRepaid);
				_transferInternal(_offer.token, _offer.receiver, _id, _amount);
				_transfer(_offer.token, msg.sender, _id, _amount);
				delete loans[_loanId];
				emit LoanDefaulted(_loanId, _amount);
				return true;
			}
		}
		revert();
	}

	/**
		@notice Create an offer to transfer ownership of a loan
		@dev This allows a lender to resell the loan to another lender
		@param _loanId ID of loan agreement
		@param _counterparty Address of the buyer
		@param _amount Sale amount in wei
		@return bool success
	 */
	function makeTransferOffer(
		uint256 _loanId,
		address _counterparty,
		uint256 _amount
	)
		external
		returns (bool)
	{
		LoanAgreement storage _offer = loans[_loanId];
		require(msg.sender == _offer.lender);
		require(_offer.tokenTotal > _offer.tokensRepaid);
		_offer.transferOffer = TransferOffer(_amount, _counterparty);
		emit LoanTransferOffered(_loanId, _counterparty, _amount);
		return true;
	}

	/**
		@notice Revoke an offer to transfer ownership
		@param _loanId ID of loan agreement
		@return bool success
	 */
	function revokeTransferOffer(uint256 _loanId) external returns (bool) {
		require(msg.sender == loans[_loanId].lender);
		TransferOffer storage t = loans[_loanId].transferOffer;
		emit LoanTransferRevoked(_loanId, t.counterparty, t.offerAmount);
		delete loans[_loanId].transferOffer;
		return true;
	}

	/**
		@notice Claim an offer to transfer ownership
		@param _loanId ID of loan agreement
		@return bool success
	 */
	function claimTransferOffer(
		uint256 _loanId
	)
		external
		payable
		returns (bool)
	{
		LoanAgreement storage _offer = loans[_loanId];
		require(msg.sender == _offer.transferOffer.counterparty);
		require(msg.value == _offer.transferOffer.offerAmount);
		require(_offer.tokenTotal > _offer.tokensRepaid);
		emit LoanTransferClaimed(
			_loanId,
			_offer.transferOffer.counterparty,
			_offer.transferOffer.offerAmount
		);
		delete _offer.transferOffer;
		_offer.lender.transfer(msg.value);
		_offer.lender = msg.sender;
		return true;
	}
}
