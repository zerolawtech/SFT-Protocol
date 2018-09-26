# SFT Token (working title)
One liner.

## Description
__ is a framework of smart contracts that build upon the ERC20 standard to allow for tokenization of equity and debt securities on the ethereum blockchain.  The framework is robust and highly modular and can be used to satisfy regulatory requirements for the complete lifecycle of a security: private and public multi-jurisdictional offerings, secondary trading (OTC, centralised, and decentralised exchanges), blah blah blah...

## How it works
SFT expands upon the ERC20 token standard.  Tokens are transferred via the `transfer` and `transferFrom` methods, however the transfer will only succeed if approved by a series of permissioning modules.  A call to `checkTransfer` returns true if the transfer is possible.  The standard configuration includes checkng a KYC/AML whitelist, tracking investor counts and limits, and restrictions on countries and accreditted status.  By implmenting other modules a variety of additional functionality is possible so as to allow compliance to laws in the countries of the issuer and investors.


## Components
 - [SecurityToken](contracts/SecurityToken.sol)
   - An ERC20 compliant token that represents a claim to ownership of a security
   - Modules may be applied to each security token to add additional permissioning or functionality
 - [IssuingEntity](contracts/IssuingEntity.sol)
   - Represents the company that issues one or more security tokens
   - Modules may be applied at this level that introduce permissioning / functionality to every security token created by the issuer
 - [KYCRegistrar](contracts/KYCRegistrar.sol)
   - The top level permission authority that grants permission for investors, issuers, and exchanges based on off-chain KYC/AML verification
   

