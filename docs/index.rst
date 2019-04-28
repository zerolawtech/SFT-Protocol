############
SFT Protocol
############

The Secured Financial Transaction Protocol (SFT) is a set of smart contracts, written in `Solidity <https://solidity.readthedocs.io/>`__ for the Ethereum blockchain, that allow for the tokenization of financial securities. It provides a robust, modular framework that is configurable for a wide range of jurisdictions, with consideration for real world needs based on today’s existing markets. SFT favors handling as much permissioning logic on-chain as possible, in order to maximize transparency for all parties involved.

The SFT Protocol was developed by `HyperLink Technology <https://hyperlink.technology>`__.

.. note::

    Code starting with ``$`` is meant to be run in your terminal. Code starting with ``>>>`` is meant to run inside the `Brownie <https://github.com/HyperLink-Technology/brownie>`__ console.

How it Works
============

SFT is designed to maximize interoperability between different network participants. Broadly speaking, these participants may be split into four categories:

* **Issuers** are entities that create and sell security tokens to fund their business operations.
* **Investors** are entities that have passed KYC/AML checks and are are able to hold or transfer security tokens.
* **Registrars** are trusted entities that provide KYC/AML services for network participants.
* **Custodians** hold tokens on behalf of investors without taking direct ownership. They may provide services such as escrow or custody, or facilitate secondary trading of tokens.

The protocol is built with two central concepts in mind: **identification** and **permission**. Each investor has their identity verified by a registrar and a unique ID hash is associated to their wallet addresses. Based on this identity information, issuers and custodians apply a series of rules to determine how the investor may interact with them.

Issuers, registrars and custodians each exist on the blockchain with their own smart contracts that define the way they interact with one another. These contracts allow different entities to provide services to each other within the ecosystem.

Security tokens in the protocol are built upon the ERC20 token standard. Tokens are transferred via the ``transfer`` and ``transferFrom`` methods, however the transfer will only succeed if it passes a series of on-chain permissioning checks. A call to ``checkTransfer`` returns true if the transfer is possible. The base configuration includes investor identification, tracking investor counts and limits, and restrictions on countries and accredited status. By implementing other modules a variety of additional functionality is possible so as to meet the needs of each individual issuer.

Components
==========

The SFT protocol is comprised of four core components:

1. :ref:`token`

    * ERC20 compliant token contracts
    * Intended to represent a corporate shareholder registry in book entry or certificated form
    * Permissioning logic to enforce enforce legal and contractural restrictions around token transfers
    * Modular design allows for optional added functionality

2. :ref:`issuing-entity`

    * Common owner contract for multiples classes of tokens created by the same issuer
    * Detailed on-chain cap table with granular permissioning capabilities
    * Modular design allows for optional added functionality
    * Multi-sig, multi-authority design provides increased security and permissioned contract management

3. :ref:`kyc`

    * Whitelists that provide identity, region, and accreditation information of investors based on off-chain KYC/AML verification
    * May be maintained by a single entity for a single token issuance, or a federation across multiple jurisdictions providing identity data for many issuers
    * Multi-sig, multi-authority design provides increased security and permissioned contract management

4. :ref:`custodian`

    * Contracts that represent an entity approved to hold tokens on behalf of multiple investors
    * Deep integration with IssuingEntity to provide accurate on-chain investor counts
    * Multiple implementations allow for a wide range of functionality including escrow services, custody, and secondary trading of tokens
    * Modular design allows for optional added functionality
    * Multi-sig, multi-authority design provides increased security and permissioned contract management

Source Code
===========

Many core components of the SFT Protocol are open sourced. You can view the code on `GitHub <https://github.com/HyperLink-Technology/SFT-Protocol>`__.

Testing and Deployment
======================

Unit testing and deployment of this project is performed with `Brownie <https://github.com/HyperLink-Technology/brownie>`__.

To run the tests:

::

    $ brownie test


.. warning:: The SFT Protocol is still under active development and has not yet undergone a third party audit. Please notify us if you find any issues in the code. **We highly recommend against using these contracts on the main-net prior to an audit by a trusted third party**.

License
=======

This project is licensed under the `Apache 2.0 <https://www.apache.org/licenses/LICENSE-2.0.html>`__ license.


Contents
========

:ref:`Keyword Index <genindex>`, :ref:`Glossary <glossary>`

.. toctree::    :maxdepth: 2

    getting-started.rst
    token.rst
    issuing-entity.rst
    kyc.rst
    custodian.rst
    multisig.rst
    modules.rst
    data-standards.rst
    glossary.rst
