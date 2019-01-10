pragma solidity >=0.4.24 <0.5.0;

import "./open-zeppelin/SafeMath.sol";
import "./SecurityToken.sol";

/** @title Custodian Contract */
contract EscrowCustodian {

	using SafeMath32 for uint32;
	using SafeMath for uint256;
	
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

	struct LoanAgreement {
		bytes32 receiver;
		address lender;
		SecurityToken token;
		IssuingEntity issuer;
		uint256 etherRepaid; // before claimed, is the amount of the loan
		uint256 tokenBalance;
		uint256[] dates; // payment due dates
		uint256[] paid; // amount that must be paid by dates
		uint256[] released; // amount in escrow that may be released after the payment
	}
	LoanAgreement[] loans;

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
			_issuer,
			msg.value,
			_released[_released.length-1],
			_dates,
			_paid,
			_released
		));
		return loans.length - 1;
	}

	

}
