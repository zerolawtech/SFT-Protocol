pragma solidity >=0.4.24 <0.5.0;

/** @title Governance Module Interface
    @dev
        these are the minimum required methods that MUST be included for
        the module to attach to IssuingEntity
 */
interface IGovernance {

    function issuer() external view returns (address);

    function modifyAuthorizedSupply(address, uint256) external returns (bool);
    function addToken(address _token) external returns (bool);

}
