pragma solidity >=0.4.24 <0.5.0;

import "./open-zeppelin/SafeMath.sol";
import "./SecurityToken.sol";

/** @title Custodian Contract */
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
		uint256 etherRepaid; // before claimed, is the amount of the loan
		uint256 tokensRepaid;
		uint256 tokenBalance;
		uint256[] dates; // payment due dates
		uint256[] paid; // amount that must be paid by dates
		uint256[] released; // amount in escrow that may be released after the payment
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

	/**
		@notice Custodian constructor
		@param _owners Array of addresses to associate with owner
		@param _threshold multisig threshold for owning authority
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
		@notice Transfers tokens out of the custodian contract
		@dev callable by custodian authorities and modules
		@param _token Address of the token to transfer
		@param _to Address of the recipient
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
		@notice Transfer token ownership within the custodian
		@dev Callable by custodian authorities and modules
		@param _token Address of the token to transfer
		@param _fromID Sender investor ID
		@param _toID Recipient investor ID
		@param _value Amount of tokens to transfer
		@param _stillOwner is sender still a beneficial owner for this issuer?
		@return bool success
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

	function offerLoan(
		bytes32 _receiver,
		SecurityToken _token,
		uint256[] _dates,
		uint256[] _paid,
		uint256[] _released
	)
		external
		payable
		returns (uint256)
	{
		require(_dates.length == _paid.length);
		require(_dates.length == _released.length);
		require(_dates[0] > now);
		require(msg.value > 0);
		for (uint256 i = 1; i < _dates.length; i++) {
			require(_dates[i] > _dates[i-1]);
			require(_paid[i] > _paid[i-1]);
			require(_released[i] >= _released[i-1]);
		}
		IssuingEntity _issuer = IssuingEntity(_token.issuer());
		loans.push(LoanAgreement(
			_receiver,
			msg.sender,
			_token,
			msg.value,
			0,
			0,
			_dates,
			_paid,
			_released
		));
		// fire an event! returning it like this isn't useful
		return loans.length - 1;
	}

	function claimOffer(uint256 _loanId) external returns (bool) {
		LoanAgreement storage _offer = loans[_loanId];
		require(issuerMap[_offer.token].getID(msg.sender) == _offer.receiver);
		require(_offer.dates[0] > now);
		require(_offer.tokenBalance == 0);
		_offer.tokenBalance = _offer.released[_offer.released.length-1];
		accept = true;
		require(_offer.token.transferFrom(
			msg.sender,
			address(this),
			_offer.tokenBalance
		));
		accept = false;
		msg.sender.transfer(_offer.etherRepaid);
		_offer.etherRepaid = 0;
		// event
		return true;
	}

	function makePayment(uint256 _loanId) external payable returns (bool) {
		LoanAgreement storage _offer = loans[_loanId];
		bytes32 _id = issuerMap[_offer.token].getID(msg.sender);
		require(_id == _offer.receiver);
		require(_offer.tokenBalance > _offer.tokensRepaid);
		_offer.etherRepaid = _offer.etherRepaid.add(msg.value);
		_offer.lender.transfer(msg.value);
		for (uint256 i = _offer.dates.length-1; i != 0; i--) {
			if (
				_offer.paid[i] <= _offer.etherRepaid &&
				_offer.released[i] > _offer.tokensRepaid
			) {
				uint256 _amount = _offer.released[i].sub(_offer.tokensRepaid);
				_offer.tokensRepaid = _offer.released[i];
				_transfer(_offer.token, msg.sender, _id, _amount);
				if (_offer.tokensRepaid == _offer.tokenBalance) {
					delete loans[_loanId];
				}
				return true;
			}
		}
		return true;
	}

	function claimCollateral(uint256 _loanId) external returns (bool) {
		LoanAgreement storage _offer = loans[_loanId];
		for (uint256 i = 0; i < _offer.dates.length; i++) {
			if (_offer.dates[i] > now) return false;
			if (_offer.paid[i] < _offer.etherRepaid) {
				bytes32 _id = issuerMap[_offer.token].getID(msg.sender);
				uint256 _amount = _offer.tokenBalance.sub(_offer.tokensRepaid);
				_transferInternal(_offer.token, _offer.receiver, _id, _amount);
				delete loans[_loanId];
				_transfer(_offer.token, msg.sender, _id, _amount);
				return true;
			}
		}
		return false;
	}

}
