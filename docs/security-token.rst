.. _security-token:

##############
Security Token
##############

Each SecurityToken contract represents a single, fungible class of securities from an issuer. The contracts conforms to the ERC20 standard, with an additional ``checkTransfer`` function available to verify if a transfer will succeed.

Token contracts are associated to an :ref:`issuing-entity` and also implement :ref:`modules` functionality. Permissioning around transfers is achieved through these components. See the respective documents for more detailed information.

It may be useful to also view the `SecurityToken.sol <https://github.com/SFT-Protocol/security-token/tree/master/contracts/SecurityToken.sol>`__ source code while reading this document.

Components
==========

Deployment
==========

Deploying a SecurityToken contract requires 4 arguments in the constructor:

* ``address _issuer``: The address of the IssuingEntity contract associated
  with this token.
* ``string _name``: The full name of the token.
* ``string _symbol``: The ticker symbol for the token.
* ``uint256 _totalSupply``: The initial total supply of tokens to create.

The total supply of tokens is assigned to the issuer at the time of creation,
with a ``Transfer`` event logged to show them as moving from 0x00.

After the contract is deployed it must be associated with the issuer via
``IssuingEntity.addToken``. Token transfers are not possible until this is done.

Functionality
=============

SecurityToken expands upon and is fully compatible with the `ERC20 Token
Standard <https://theethereum.wiki/w/index.php/ERC20_Token_Standard>`__.

Constants
---------

The following public variables cannot be changed after creation, and can be considered constants.

* ``name``: The full name of the security token.
* ``symbol``: The ticker symbol for the token.
* ``decimals``: The number of decimal places for the token. This is a constant always set to 0, as you cannot legally fractionalize a security.
* ``ownerID``: The ID hash of the issuer associated with this token.
* ``issuer``: The address of the associated IssuingEntity contract

Total Supply and Token Balances
-------------------------------

The standard ``totalSupply`` and``balanceOf`` functions may be called to check the total token supply or balance at an address, respectively.

Additionally there are two more functions relating to the total supply:

* ``treasurySupply``: Returns the number of tokens held by the issuer.
* ``circulatingSupply``: Returns the total supply, less the amount held by the issuer.

Token Transfers
---------------

Token transfers occur via the standard ``transfer`` and ``transferFrom`` functions.  For a transfer to succeed it must first pass a series of checks:

* The tokens cannot be locked.
* The sender must have a sufficient balance.
* The sender and receiver must be verified in a registrar associated to the issuer.
* The sender and receiver must not be restricted by the registrar or the issuer.
* The transfer must not result in any issuer-imposed investor limits being exceeded.
* The transfer must be permitted by all active modules.

The ``checkTransfer`` function is used to check if a transfer will succeed without attempting it.

Transfers between two addresses that are associated to the same ID do not undergo the same level of restrictions, as there is no change of ownership occuring.

All transfers will log the ``Transfer`` event. Transfers where there is a change of ownership will also log``IssuingEntity.TransferOwnership``.

Users may call ``approve`` and ``transferFrom`` in the same way that they would a normal ERC20.  Approval may be given to any address, but a transfer can only be initiated by an address that is known by one of the associated registrars. The same transfer checks also apply for both the sender and receiver, as if the transfer was done directly.

If the caller and sender addresses are both associated to the same ID, ``transferFrom`` may be called without giving prior approval. In this way an investor can easily recover tokens when a private key is lost or compromised.

Issuer Balances and Token Transfers
-----------------------------------

Tokens held by the issuer will always be at the address of the IssuingEntity contract.  A call to ``SecurityToken.treasurySupply()`` will return the same result as ``SecurityToken.balanceOf(SecurityToken.issuer())``.

As a result of this, the following non-standard behaviours exist:

* Any address associated with the issuer can transfer tokens from the IssuingEntity contract using ``transfer``.
* Attempting to send tokens to any address associated with the issuer will result in the tokens being sent to the IssuingEntity contract.

The issuer may call ``transferFrom`` to move tokens between any addresses without prior approval. Transfers of this type must still pass the normal checks, with the exception that the sending address may be restricted.  In this way the issuer can aid investors with token recovery in the event of a lost or compromised private key, or force a transfer in the event of a court order or sanction.

Integration
===========

After the contract is deployed it must be associated with the issuer via
``IssuingEntity.addToken``. Token transfers are not possible until this is done.

