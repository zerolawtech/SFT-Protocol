pragma solidity >=0.4.24 <0.5.0;


/**
    @title Governance Module Minimal Implementation
    @dev
        This is included purely for testing purposes, a real implementation
        will include some form of voting mechanism. Calls should only return
        true once an action has been approved.
*/
contract GovernanceMinimal {

    address public issuer;
    
    /**
        @notice Base constructor
        @param _issuer IssuingEntity contract address
     */
    constructor(address _issuer) public {
        issuer = _issuer;
    }

    /**
        @notice Approval to modify authorized supply
        @dev Called by IssuingEntity.modifyAuthorizedSupply
        @param _token Token contract seeking to modify authorized supply
        @param _value New authorized supply value
        @return permission boolean
     */
    function modifyAuthorizedSupply(
        address _token,
        uint256 _value
    )
        external
        returns (bool)
    {
        require (msg.sender == issuer);
        return true;
    }

    /**
        @notice Approval to attach a new token contract
        @dev Called by IssuingEntity.addToken
        @param _token Token contract address
        @return permission boolean
     */
    function addToken(address _token) external returns (bool) {
        require (msg.sender == issuer);
        return true;
    }

}
