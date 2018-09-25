# SFT Token (working title)
One liner.

## Description
__ is a framework of smart contracts that build upon the ERC20 standard to allow for tokenization of equity and debt securities on the ethereum blockchain.  The framework is robust and highly modular and can be used to satisfy regulatory requirements for the complete lifecycle of a security: private and public multi-jurisdictional offerings, secondary trading (OTC, centralised, and decentralised exchanges), blah blah blah...

## How it works
SFT expands upon the ERC20 token standard.  Tokens are transferred via the `transfer` and `transferFrom` methods, however the transfer will only succeed if approved by a series of permissioning modules.  A call to `checkTransfer` returns true if the transfer is possible.  The standard configuration includes checkng a KYC/AML whitelist, tracking investor counts and limits, and restrictions on countries and accreditted status.  By implmenting other modules a variety of additional functionality is possible so as to allow compliance to laws in the countries of the issuer and investors.


## Components
 - [KYCRegistrar](contracts/KYCRegistrar.sol): does stuff
 - [IssuingEntity](contracts/IssuingEntity.sol): does other stuff
 - [SecurityToken](contracts/SecurityToken.sol): does even more stuff
