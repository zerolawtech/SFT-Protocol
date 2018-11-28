############
SFT Protocol
############

The Secured Financial Transaction (SFT) Protocol is a set of compliance-oriented smart contracts, written in `Solidity <https://solidity.readthedocs.io/en/v0.5.0/>`__ for the Ethereum blockchain, that allow for the tokenization of debt and equity based securities. It provides a robust, flexible framework allowing issuers and investors to retain regulatory compliance throughout primary issuance and multi-jurisdictional secondary trading.

How it Works
============

SFT is designed to maximize interoperability between different network participants. Broadly speaking, these participants may be split into four categories:

* **Investors** are entities that have passed KYC/AML checks and are are able to hold or transfer security tokens.
* **Issuers** are entities that create and sell security tokens to fund their business operations.
* **Registrars** are trusted entities that provide KYC/AML services for network participants.
* **Custodians** are trusted entities that may hold tokens on behalf of multiple investors and facilitate secondary trading of tokens.

The protocol is built with two central concepts in mind: **identification** and **permission**. Each investor has their identity verified by a registrar and a unique ID hash is associated to their wallet addresses. Based on this identity information, issuers and custodians apply a series of rules to determine how the investor may interact with them.

Issuers, registrars and custodians each exist on the blockchain with their own smart contracts that define the way they interact with one another. These contracts allow different entities to provide services to each other within the ecosystem.

Security tokens in the protocol are built upon the ERC20 token standard. Tokens are transferred via the ``transfer`` and ``transferFrom`` methods, however the transfer will only succeed if it passes a series of on-chain compliance requirements. A call to ``checkTransfer`` returns true if the transfer is possible. The base configuration includes investor identification, tracking investor counts and limits, and restrictions on countries and accredited status. By implementing other modules a variety of additional functionality is possible so as to allow compliance to laws in the countries of the issuer and investors.

Components
==========

The SFT protocol is comprised of four core contracts:

1. :ref:`security-token`

    * ERC20 compliant token contract
    * Intended to represent a claim to ownership of securities
    * Permissioning logic to enforce compliance in all token transfers
    * Modular design allows for optional added functionality

2. :ref:`issuing-entity`

    * Owner contract for tokens created by the same issuer
    * Handles common compliance logic for all the issuer's tokens
    * Modular design allows for optional added functionality
    * Multi-sig, multi-authority design provides increased security and permissioned contract management

3. :ref:`kyc-registrar`

    * Whitelists that provide identity, region, and accreditation information of investors based on off-chain KYC/AML verification
    * May be maintained by a single entity or a federation across multiple jurisdictions
    * Multi-sig, multi-authority design provides increased security and permissioned contract management

4. :ref:`custodian`

    * Contracts that represent an entity approved to hold tokens on behalf of multiple investors
    * Interacts with IssuingEntity to provide accurate on-chain investor counts
    * Intended to be used by broker/dealers and exchanges
    * Modular design allows for optional added functionality
    * Multi-sig, multi-authority design provides increased security and permissioned contract management

Yellow Paper
============

The `Yellow Paper <https://github.com/HyperLink-Capital/sft-protocol/blob/master/docs/SFT-Protocol-Yellowpaper.pdf>`__ provides a more detailed overview of how the protocol is structrued.

Source Code
===========

The SFT Protocol is open source. You can view the code on `GitHub <https://github.com/HyperLink-Capital/sft-protocol>`__.

Testing and Deployment
======================

Unit testing and deployment of this project is performed with `Brownie <https://github.com/iamdefinitelyahuman/brownie>`__.

.. warn:: The SFT Protocol is still under active development and has not yet undergone a third party audit. Please notify us if you find any issues in the code. We highly recommend against using these contracts prior to an audit by a trusted third party.

License
=======

This project is licensed under the `Apache 2.0 <https://www.apache.org/licenses/LICENSE-2.0.html>`__ license.


Contents
========

:ref:`Keyword Index <genindex>`, :ref:`Glossary <glossary>`

.. toctree::    :maxdepth: 2

    getting-started.rst
    security-token.rst
    issuing-entity.rst
    kyc-registrar.rst
    custodian.rst
    security-considerations.rst
    multisig.rst
    modules.rst
    data-standards.rst
    glossary.rst
