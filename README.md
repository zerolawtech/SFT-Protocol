# SFT Protocol

## Description

The SFT protocol is a set of compliance-oriented smart contracts built on the Ethereum blockchain that allow for the tokenization of debt and equity based securities. It provides a robust, flexible framework allowing issuers and investors to retain regulatory compliance throughout primary issuance and multi-jurisdictional secondary trading.

## How it works

SFT expands upon the ERC20 token standard. Tokens are transferred via the `transfer` and `transferFrom` functions, however the transfer will only succeed if approved by a series of permissioning modules. A call to `checkTransfer` returns true if the transfer is possible. The standard configuration includes checking a KYC/AML whitelist, tracking investor counts and limits, and restrictions on countries and accreditted status. By implmenting other modules a variety of additional functionality is possible so as to allow compliance to laws in the countries of the issuer and investors.

## Components

- [SecurityToken](contracts/SecurityToken.sol)
  - ERC20 compliant tokens intended to represent a claim to ownership of securities
  - Modules may be applied to each security token to add additional permissioning or functionality
- [IssuingEntity](contracts/IssuingEntity.sol)
  - Central owner contract for tokens created by the same issuer
  - Modules may be applied at this level that introduce permissioning / functionality to all associated security token contracts
- [KYCRegistrar](contracts/KYCRegistrar.sol)
  - Whitelists that provide identity, region, and accreditation information of investors based on off-chain KYC/AML verification
- [Custodian](contracts/Custodian.sol)
  - Contracts that represent an entity approved to hold tokens for multiple investors
  - Simple base interface allows for wide customisation depending on the needs of the owner

## KYCRegistrar

KYCRegistrar contracts are registries that hold information on identity, region, and rating of investors.

Registries may be maintained by a single entity, or a federation of entities where each are approved to provide identification services for their specific jurisdiction. The contract owner can authorize other entities to add investors within specified countries.

Contract authorities associate addresses to ID hashes that denotes the identity of the investor who owns the address. More than one address may be associated to the same hash. Anyone can call `getID` to see which hash is associated to an address, and then using this ID call functions to query information about the investor's region and accreditation rating.

*See the [KYCRegistrar](docs/kyc-registrar.md) page for in-depth details.*

## IssuingEntity

Before an issuer can create a security token they must deploy an IssuingEntity contract. This contract has several key purposes:

- Holds a whitelist of associated KYC registries that investor data can be pulled from
- Tracks investor counts and total balances across all security tokens deployed by the issuer
- Enforces permissions relating to investor limits and authorised countries
- Holds a mapping of hashes for legal documents related to the issuer

*See the [IssuingEntity](docs/issuing-entity.md) page for in-depth details.*

## SecurityToken

SecurityToken represents a single, fungible class of securities from an issuer. It conforms to the ERC20 standard, with an additional `checkTransfer` function available to verify if a transfer will succeed. Before tokens can be transferred, all of the following checks must pass:

- Sender and receiver addresses must be validated by a KYC registrar
- Issuer imposed limits on investor counts: global, country specific, and accreditation rating specific
- Optional permissions added via modules applied at the SecurityToken and IssuingEntity level

Transfers that move tokens between different addressses owned by the same entity (as identified in the KYC registrar) are not as heavily restricted because there is no change of ownership. Any address belonging to a single entity can call `transferFrom` and move tokens from any of their wallets. The issuer can use the same function to move any tokens between any address.

*See the [SecurityToken](docs/security-token.md) page for in-depth details.*

## Custodian

TODO

*See the [Custodian](docs/custodian.md) page for in-depth details.*

## Modules

Issuers may attach modules to IssuingEntity or SecurityToken. When a module is attached, a call to `getBindings` checks the hook points that the module should be called at. Depending on the functionality of the module it may attach at any of the following hook points:

- `checkTransfer`: called to verify permissions before a transfer is allowed
- `transferTokens`: called after a transfer has completed successfully
- `balanceChanged`: called after a balance has changed, such that there was not a corresponding change to another balance (e.g. token minting and burning)

Modules can also directly change the balance of any address. Modules that are active at the IssuingEntity level can call this function on any security token, modules at the SecurityToken level can only call it on the token they are attached to.

When a module is no longer required it can be detached. This should always be done in order to optimize gas costs.

The wide range of functionality that modules can hook into allows for many different applications. Some examples include: crowdsales, country/time based token locks, voting rights, dividend payments, decentralised trading, and bond redemption.

*See the [Modules](docs/modules.md) page for in-depth details.*

## Third-Party Integration

*See the [Third Party Integration](docs/third-party-integration.md) page for in-depth details.*

## License

This project is licensed under the [Apache 2.0](https://www.apache.org/licenses/LICENSE-2.0.html) license.