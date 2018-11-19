############
SFT Protocol
############

The SFT protocol is a set of compliance-oriented smart contracts built on the Ethereum blockchain that allow for the tokenization of debt and equity based securities. It provides a robust, flexible framework allowing issuers and investors to retain regulatory compliance throughout primary issuance and multi-jurisdictional secondary trading.

How it works
------------

SFT expands upon the ERC20 token standard. Tokens are transferred via the ``transfer`` and ``transferFrom`` functions, however the transfer will only succeed if approved by a series of permissioning modules. A call to ``checkTransfer`` returns true if the transfer is possible. The standard configuration includes checking a KYC/AML whitelist, tracking investor counts and limits, and restrictions on countries and accredited status. By implementing other modules a variety of additional functionality is possible so as to allow compliance to laws in the countries of the issuer and investors.

Components
----------

1. :ref:`security-token`

    a. ERC20 compliant tokens intended to represent a claim to ownership of securities
    b. Modules may be applied to each security token to add additional permissioning or functionality

2. :ref:`issuing-entity`

    a. Central owner contract for tokens created by the same issuer
    b. Modules may be applied at this level that introduce permissioning / functionality to all associated security token contracts

3. :ref:`kyc-registrar`

    a. Whitelists that provide identity, region, and accreditation information of investors based on off-chain KYC/AML verification

4. :ref:`custodian`

    a. Contracts that represent an entity approved to hold tokens for multiple investors
    b. Base interface that allows for wide customisation depending on the needs of the owner

5. :ref:`modules`
    a. Wide range of functionality that modules can hook into allows for many different applications


Testing and Deployment
----------------------
   Unit testing and deployment of this project is performed with `brownie <https://github.com/iamdefinitelyahuman/brownie>`__.

Third-Party Integration
-----------------------
   See :ref:`third-party-integration` for in-depth details.

License
-------
   This project is licensed under the `Apache 2.0 <https://www.apache.org/licenses/LICENSE-2.0.html>`__ license.


Contents
========

:ref:`Keyword Index <genindex>`, :ref:`Search Page <search>`

.. toctree::    :maxdepth: 2

    security-token.rst
    issuing-entity.rst
    kyc-registrar.rst
    custodian.rst
    multisig.rst
    modules.rst
    multisig.rst
    third-party-integration.rst
    data-standards.rst
