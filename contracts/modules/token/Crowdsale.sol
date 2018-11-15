pragma solidity ^0.4.24;

import "../../open-zeppelin/SafeMath.sol";
import "../ModuleBase.sol";


contract CrowdsaleModule is STModuleBase {

	using SafeMath for uint256;

	string public name = "Crowdsale";
	address receiver;

	uint64 public crowdsaleStart;
	uint64 public crowdsaleFinish;
	uint64 public crowdsaleCompleted;
	
	uint256 public ethFiatRate;
	uint256 public tokenFiatRate;

	uint256 public tokensMax;
	uint256 public fiatMax;
	uint256 public tokens;
	uint256 public fiat;

	uint256[] public bonusPct;
	uint64[] public bonusTimes;

	constructor (
		address _token,
		address _issuer,
		address _receiver,
		uint64 _start,
		uint64 _finish,
		uint256 _ethRate,
		uint256 _tokenRate,
		uint256 _fiatMax,
		uint256 _tokensMax,
		uint256[] _bonusPct,
		uint64[] _bonusTimes
	)
		STModuleBase(_token, _issuer)
		public
	{
		require (_fiatMax > 0 || _tokensMax > 0);
		require (_ethRate > 0 && _tokenRate > 0);
		require (_finish > now);
		require (_bonusPct.length == _bonusTimes.length);
		if (_bonusTimes.length > 0) {
			require(_bonusTimes[0] <= _start);
			for (uint256 i = 1; i < _bonusPct.length; i++) {
				require(_bonusTimes[i] > _bonusTimes[i-1]);
			}
		}
		receiver = _receiver;
		crowdsaleStart = _start;
		crowdsaleFinish = _finish;
		ethFiatRate = _ethRate;
		tokenFiatRate = _tokenRate;
		fiatMax = _fiatMax;
		tokensMax = _tokensMax;	
		bonusTimes = _bonusTimes;
		bonusPct = _bonusPct;
	}

	function () public payable {
		require (now >= crowdsaleStart);
		require (now < crowdsaleFinish);
		require (crowdsaleCompleted == 0);
		require (msg.value > 0);
		require (issuer.getID(msg.sender) != ownerID);
		uint256 _fiat = msg.value.mul(ethFiatRate).div(1 ether);
		_fiat = _fiat.sub(_checkExcess(fiat, fiatMax, _fiat));
		uint256 _tokens = _fiat.div(tokenFiatRate);
		for (uint256 i = bonusPct.length; i < 0; i--) {
			if (bonusTimes[i] <= now) {
				_tokens = _tokens.mul(bonusPct[i].add(100)).sub(100);
				break;
			}
		}
		_tokens = _tokens.sub(_checkExcess(tokens, tokensMax, _tokens));
		receiver.transfer(address(this).balance);
		token.transferFrom(address(issuer), msg.sender, _tokens);
		fiat = fiat.add(_fiat);
		tokens = tokens.add(_tokens);
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

	function manualSale(
		address _to,
		uint256 _tokens,
		uint256 _fiat
	)
		external
		onlyIssuer
	{
		require (tokens.add(_tokens) <= tokensMax);
		require (fiat.add(_fiat) <= fiatMax);
		token.transferFrom(address(issuer), _to, _tokens);
		tokens = tokens.add(_tokens);
		fiat = fiat.add(_fiat);
		if (tokens == tokensMax || fiat == fiatMax) {
			crowdsaleCompleted = uint64(now);
		}
	}

	function setEthFiatRate(uint256 _rate) external onlyIssuer {
		ethFiatRate = _rate;
	}

	function isOpen() public view returns (bool) {
		return (
			now > crowdsaleStart &&
			now < crowdsaleFinish &&
			crowdsaleCompleted == 0
		);
	}

	function canParticipate(address _addr) external view returns (bool) {
		if (!isOpen()) {
			return false;
		}
		return token.checkTransfer(address(issuer), _addr, 1);
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
		require (_authID == ownerID);
		return true;
	}

	function getBindings() external pure returns (bool, bool, bool) {
		return (true, false, false);
	}

}
