pragma solidity ^0.4.24;

import "../../open-zeppelin/SafeMath.sol";
import "./BaseCheckpoint.sol";


contract DividendModule is CheckpointModule {

  using SafeMath for uint256;
  
  uint256 public dividendTime;
  uint256 public dividendAmount;
  uint256 public claimExpiration;
  
  mapping (address => bool) claimed;
  
  event DividendIssued(uint256 time, uint256 amount);
  event DividendClaimed(address beneficiary, uint256 amount);
  event DividendExpired(uint256 unclaimedAmount);
  
  function issueDividend(uint256 _claimPeriod) public onlyIssuer payable {
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
    require (!claimed[_beneficiary]);
    uint256 _value = _getBalance(_beneficiary).mul(dividendAmount).div(totalSupply);
    claimed[_beneficiary] = true;
    _beneficiary.transfer(_value);
    emit DividendClaimed(_beneficiary, _value);
  }
  
  function claimMany(address[] _beneficiaries) public {
    for (uint256 i = 0; i < _beneficiaries.length; i++) {
      claimDividend(_beneficiaries[i]);
    }
  }
  
  function closeDividend() public onlyIssuer {
    require (claimExpiration > 0);
    require (now > claimExpiration);
    emit DividendExpired(address(this).balance);
    msg.sender.transfer(address(this).balance);
    require (token.detachModule(address(this)));
  }

}