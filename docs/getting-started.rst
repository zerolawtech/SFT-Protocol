.. _getting-started:

###############
Getting Started
###############

This is a quick explanation of the minimum steps required to deploy and use each contract of the protocol.

To setup a simple test environment using brownie:


::

    brownie console
    >>> run('simple')


This runs `simple.py <https://github.com/SFT-Protocol/security-token/tree/master/deployments/simple.py>`__ which:

* Deploys ``KYCRegistrar`` from ``accounts[0]``
* Deploys ``IssuingEntity`` from ``accounts[1]``
* Deploys ``SecurityToken`` from ``accounts[1]`` with an initial total supply of 1,000,000 tokens
* Associates the contracts
* Approves ``accounts[2:8]`` in ``KYCRegistrar``, with investor ratings 1-2 and country codes 1-3
* Approves investors from country codes 1-3 in ``IssuingEntity``

From this configuration, the contracts are ready to transfer tokens:

..

    >>> SecurityToken[0].transfer(accounts[2], 1000)
    >>> SecurityToken[0].transfer(accounts[3], 1000, {'from': accounts[2]})

KYC Registrar
=============

To setup an investor registry, deploy `KYCRegistrar.sol <https://github.com/SFT-Protocol/security-token/tree/master/contracts/KYCRegistrar.sol>`__. Owner addresses will then be able to add investors using ``KYCRegistrar.addInvestor`` or approve other whitelisting authorities with ``KYCRegistrar.addAuthority``.

See the :ref:`kyc-registrar` page for a detailed explanation of how to use this contract.

Issuing Tokens
==============

Issuing tokens and being able to transfer them requires the following steps:

1. Deploy `IssuingEntity.sol <https://github.com/SFT-Protocol/security-token/tree/master/contracts/IssuingEntity.sol>`__.
2. Call ``IssuingEntity.setRegistrar`` to add one or more investor registries. You may maintain your own registry and/or use those belonging to trusted third parties.
3. Deploy `SecurityToken.sol <https://github.com/SFT-Protocol/security-token/tree/master/contracts/SecurityToken.sol>`__. Enter the address of the issuer contract from step 1 in the constructor. The total supply of tokens will be initially creditted to the issuer.
4. Call ``IssuingEntity.addToken`` to attach the token to the issuer.
5. Call ``IssuingEntity.setCountries`` to approve investors from specific countries to hold the tokens.

At this point, the issuer will be able to transfer tokens to any address that has been whitelisted by one of the approved investor registries *if the investor meets the country and rating requirements*.

Note that the issuer's balance is assigned to the IssuingEntity contract. The issuer can transfer these tokens with a normal call to ``SecurityToken.transfer`` from any approved address. Sending tokens to any address associated with the issuer will increase the balance on the IssuingEntity contract.

See the :ref:`issuing-entity` and :ref:`security-token` pages for detailed explanations of how to use these contracts.

Transferring Tokens
===================

SecurityToken.sol is based on the `ERC20 Token Standard <https://theethereum.wiki/w/index.php/ERC20_Token_Standard>`__. Token transfers may be performed in the same ways as any token using this standard. However, in order to send or receive tokens you must:

* Be approved in one of the KYC registries associated to the token issuer
* Meet the approved country and rating requirements as set by the issuer
* Pass any additional checks set by the issuer

You can check if a transfer will succeed without performing a transaction by calling the ``SecurityToken.checkTransfer`` method within the token contract.

Restrictions imposed on investor limits, approved countries and minimum ratings are only checked when receiving tokens. Unless an address has been explicitly blocked, it will always be able to send an existing balance. For example, an investor may purchase tokens that are only available to accredited investors, and then later their accreditation status expires. The investor may still transfer the tokens they already have, but may not receive any more tokens.

Transferring a balance between two addresses associated with the same investor ID does not have the same restrictions imposed, as there is no change of ownership. An investor with multiple addresses may call ``SecurityToken.transferFrom`` to move tokens from any of their addresses without first using the ``SecurityToken.approve`` method. The issuer can also use ``SecurityToken.transferFrom`` to move any investor's tokens, without prior approval.

See the :ref:`security-token` page for a detailed explanation of how to use this contract.

Custodians
==========

To set up a custodian contract to send and receive tokens, deploy `Custodian.sol <https://github.com/SFT-Protocol/security-token/tree/master/contracts/Custodian.sol>`__ and then attach it to an IssuingEntity with ``IssuingEntity.addCustodian``. At this point, investors may send tokens into the custodian contract just like they would any other address.

The ``Custodian.transfer`` function allows you to send tokens out of the contract. You may modify the list of beneficial owners using ``addInvestors`` and ``removeInvestors``.

See the :ref:`custodian` page for a detailed explanation of how to use this contract.
