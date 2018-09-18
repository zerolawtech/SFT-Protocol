pragma solidity ^0.4.24;

import "./open-zeppelin/safemath.sol";
import "./securitytoken.sol";

contract ModuleBase {

  bytes32 public issuerID;
  InvestorRegistrar public registrar;
  SecurityToken public token;

  modifier onlyIssuer () {
    require (registrar.idMap(msg.sender) == issuerID);
    require (!registrar.isRestricted(issuerID));
    _;
  }
  
  modifier onlyToken() {
    require (msg.sender == address(token));
    _;
  }

}

contract CheckpointModule is ModuleBase {

  uint256 time;
  uint256 totalSupply;
  mapping (address => uint256) balance;
  mapping (address => bool) zeroBalance;
  
  constructor(address _token, uint256 _time) public {
    require (_time >= now);
    token = SecurityToken(_token);
    issuerID = token.issuerID();
    registrar = InvestorRegistrar(token.registrar());
    totalSupply = token.totalSupply();
    time = _time;
  }
  
  function _getBalance(address _owner) internal view returns (uint256) {
    if (balance[_owner] > 0) return balance[_owner];
    if (zeroBalance[_owner]) return 0;
    return token.balanceOf(_owner);
  }
  
  function balanceChanged(address _owner, uint256 _old, uint256 _new) external onlyToken returns (bool) {
    if (now < time) return true;
    if (balance[_owner] > 0) return true;
    if (zeroBalance[_owner]) return true;
    if (_old > 0) {
      balance[_owner] = _old;
    } else {
      zeroBalance[_owner] = true;
    }
    return true;
  }
  
  function totalSupplyChanged(uint256 _old, uint256 _new) external onlyToken returns (bool) {
    if (now < time) {
      totalSupply = _new;
    }
    return true;
  }

}


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
    require (token.detachBalanceModule(address(this)));
  }

}