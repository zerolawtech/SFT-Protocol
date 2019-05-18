.. _custodian:

##########
Custodians
##########

Custodian contracts are approved to hold tokens on behalf of multiple investors. Each custodian must be individually approved by an issuer before they can receive tokens.

There are two broad categories of custodians:

* **Owned** custodians are contracts that are controlled and maintained by a known legal entity. Examples of owned custodians include broker/dealers or centralized exchanges.
* **Autonomous** custodians are contracts without an owner. Once deployed there is no authority capable of exercising control over the contract. Examples of autonomous custodians include escrow services, privacy protocols and decentralized exchanges.

It may be useful to view source code for the following contracts while reading this section:

* `OwnedCustodian.sol <https://github.com/HyperLink-Technology/SFT-Protocol/blob/master/contracts/custodians/OwnedCustodian.sol>`__: Standard owned custodian contract with ``Multisig`` and ``Modular`` functionality.
* `IBaseCustodian.sol <https://github.com/HyperLink-Technology/SFT-Protocol/blob/master/contracts/interfaces/IBaseCustodian.sol>`__: The minimum contract interface required for a custodian to interact with an ``IssuingEntity`` contract.

.. warning:: An issuer should not approve a Custodian if the contract source code cannot be verified, or it is using a non-standard implementation that has not undergone a thorough audit. The SFT protocol includes a standard owned Custodian contract that allows for customization through modules.

.. toctree::    :maxdepth: 2

    custodian-basics.rst
    owned-custodian.rst
