pragma solidity ^0.4.24;

import "../../open-zeppelin/SafeMath.sol";
import "../ModuleBase.sol";


contract Crowdsale is STModuleBase {

	using SafeMath for uint256;

	address receiver;

	uint64 public crowdsaleStart;
	uint64 public crowdsaleFinish;
	uint64 public crowdsaleCompleted;
	
	uint256 public ethFiatRate;
	uint256 public tokenFiatRate;

	uint256 public maxTokensSold;
	uint256 public maxFiatRaised;
	uint256 public tokensSold;
	uint256 public fiatRaised;


	constructor (
		address _token,
		address _issuer,
		address _receiver
	)
		STModuleBase(_token, _issuer)
		public
	{
		receiver = _receiver;
	}

	function () public payable {
		require (now >= crowdsaleStart);
		require (now < crowdsaleFinish);
		require (crowdsaleCompleted == 0);
		require (msg.value > 0);
		uint256 _fiat = msg.value.mul(ethFiatRate).div(1 ether);
		_fiat = _fiat.sub(_checkExcess(fiatRaised, maxFiatRaised, _fiat));
		uint256 _tokens = _fiat.div(tokenFiatRate);
		_tokens = _tokens.sub(_checkExcess(tokensSold, maxTokensSold, _tokens));
		receiver.transfer(address(this).balance);
		token.transferFrom(address(issuer), msg.sender, _tokens);
		fiatRaised = fiatRaised.add(_fiat);
		tokensSold = tokensSold.add(_tokens);
	}

	function _checkExcess(
		uint256 _sold,
		uint256 _max,
		uint256 _sent
	)
		internal
		returns (uint256 _excess)
	{
		if (_max == 0 || _sold.add(_sent) < _max) {
			return 0;
		}
		_excess = _sold.add(_sent).sub(_max);
		msg.sender.transfer(msg.value.mul(_excess).div(_sent));
		crowdsaleCompleted = uint64(now);
		return _excess;
	}

	function manualSale(address _to, uint256 _tokens, uint256 _fiat) external onlyIssuer {
		require (tokensSold.add(_tokens) <= maxTokensSold);
		require (fiatRaised.add(_fiat) <= maxFiatRaised);
		token.transferFrom(address(issuer), _to, _tokens);
		tokensSold = tokensSold.add(_tokens);
		fiatRaised = fiatRaised.add(_fiat);
		if (tokensSold == maxTokensSold || fiatRaised == maxFiatRaised) {
			crowdsaleCompleted = uint64(now);
		}
	}

	function setEthFiatRate(uint256 _rate) external onlyIssuer {
		ethFiatRate = _rate;
	}

	function checkTransfer(
		address[2],
		bytes32 _authID,
		bytes32[2],
		uint8[2],
		uint16[2],
		uint256
	)
		external
		view
		returns (bool)
	{
		require (_authID == issuer.issuerID());
		return true;
	}

	function getBindings() external pure returns (bool, bool, bool) {
		return (true, false, false);
	}

}
