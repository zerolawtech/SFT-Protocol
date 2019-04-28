# SFT Protocol

## Description

The SFT protocol is a set of smart contracts, written in Solidity for the Ethereum blockchain, that allow for the tokenization of financial securities. It provides a robust, modular framework that is configurable for a wide range of jurisdictions, with consideration for real world needs based on today’s existing markets. SFT favors handling as much permissioning logic on-chain as possible, in order to maximize transparency for all parties involved.

## How it Works

SFT is designed to maximize interoperability between different network participants. Broadly speaking, these participants may be split into four categories:

* **Issuers** are entities that create and sell security tokens to fund their business operations.
* **Investors** are entities that have passed KYC/AML checks and are are able to hold or transfer security tokens.
* **Registrars** are trusted entities that provide KYC/AML services for network participants.
* **Custodians** hold tokens on behalf of investors without taking direct ownership. They may provide services such as escrow or custody, or facilitate secondary trading of tokens.

The protocol is built with two central concepts in mind: **identification** and **permission**. Each investor has their identity verified by a registrar and a unique ID hash is associated to their wallet addresses. Based on this identity information, issuers and custodians apply a series of rules to determine how the investor may interact with them.

Issuers, registrars and custodians each exist on the blockchain with their own smart contracts that define the way they interact with one another. These contracts allow different entities to provide services to each other within the ecosystem.

Security tokens in the protocol are built upon the ERC20 token standard. Tokens are transferred via the ``transfer`` and ``transferFrom`` methods, however the transfer will only succeed if it passes a series of on-chain permissioning checks. A call to ``checkTransfer`` returns true if the transfer is possible. The base configuration includes investor identification, tracking investor counts and limits, and restrictions on countries and accredited status. By implementing other modules a variety of additional functionality is possible so as to meet the needs of each individual issuer.

## Components

The SFT protocol is comprised of four core components:

1. **Token**

    * ERC20 compliant token contracts
    * Intended to represent a corporate shareholder registry in book entry or certificated form
    * Permissioning logic to enforce enforce legal and contractural restrictions around token transfers
    * Modular design allows for optional added functionality

2. **IssuingEntity**

    * Common owner contract for multiples classes of tokens created by the same issuer
    * Detailed on-chain cap table with granular permissioning capabilities
    * Modular design allows for optional added functionality
    * Multi-sig, multi-authority design provides increased security and permissioned contract management

3. **KYC**

    * Whitelists that provide identity, region, and accreditation information of investors based on off-chain KYC/AML verification
    * May be maintained by a single entity for a single token issuance, or a federation across multiple jurisdictions providing identity data for many issuers
    * Multi-sig, multi-authority design provides increased security and permissioned contract management

4. **Custodian**

    * Contracts that represent an entity approved to hold tokens on behalf of multiple investors
    * Deep integration with IssuingEntity to provide accurate on-chain investor counts
    * Multiple implementations allow for a wide range of functionality including escrow services, custody, and secondary trading of tokens
    * Modular design allows for optional added functionality
    * Multi-sig, multi-authority design provides increased security and permissioned contract management

## Documentation

In-depth documentation is hosted at [Read the Docs](https://sft-protocol.readthedocs.io).

## Develoment Progress

The SFT Protocol is still under active development and has not yet undergone a third party audit. Please notify us if you find any issues in the code. We highly recommend against using these contracts prior to an audit by a trusted third party.

## Testing and Deployment

Unit testing and deployment of this project is performed with [Brownie](https://github.com/HyperLink-Technology/brownie).

To run the tests:

```bash
$ brownie test
```

## Getting Started

See the [Getting Started](https://sft-protocol.readthedocs.io/en/latest/getting-started.html) page for in-depth details on how to deploy the contracts so you can interact with them.

To setup an interactive brownie test environment:

```bash
$ brownie console
>>> run('deployment')
```

This runs the `main` function in [scripts/deployment.py](scripts/deployment.py) which:

* Deploys ``KYCRegistrar`` from ``accounts[0]``
* Deploys ``IssuingEntity`` from ``accounts[0]``
* Deploys ``SecurityToken`` from ``accounts[0]`` with an initial authorized supply of 1,000,000
* Associates the contracts
* Approves ``accounts[1:7]`` in ``KYCRegistrar``, with investor ratings 1-2 and country codes 1-3
* Approves investors from country codes 1-3 in ``IssuingEntity``

From this configuration, the contracts are ready to mint and transfer tokens:

```python
>>> token = SecurityToken[0]
>>> token.mint(accounts[1], 1000, {'from': accounts[0]})

Transaction sent: 0x77ec76224d90763641971cd61e99711c911828053612cc16eb2e5d7faa20815e
SecurityToken.mint confirmed - block: 13   gas used: 229092 (2.86%)
<Transaction object '0x77ec76224d90763641971cd61e99711c911828053612cc16eb2e5d7faa20815e'>
>>>
>>> token.transfer(accounts[2], 1000, {'from': accounts[1]})

Transaction sent: 0x29d9786ca39e79714581b217c24593546672e31dbe77c64804ea2d81848f053f
SecurityToken.transfer confirmed - block: 14   gas used: 192451 (2.41%)
<Transaction object '0x29d9786ca39e79714581b217c24593546672e31dbe77c64804ea2d81848f053f'>
>>>
```

## License

This project is licensed under the [Apache 2.0](https://www.apache.org/licenses/LICENSE-2.0.html) license.
