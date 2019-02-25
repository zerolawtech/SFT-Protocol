.. _security-token:

#############
SecurityToken
#############

Each SecurityToken contract represents a single, fungible class of securities from an issuer. The contracts conforms to the `ERC20 Token
Standard <https://theethereum.wiki/w/index.php/ERC20_Token_Standard>`__, with an additional ``checkTransfer`` function available to verify if a transfer will succeed.

Token contracts are associated to an :ref:`issuing-entity` and also implement :ref:`modules` functionality. Permissioning around transfers is achieved through these components. See the respective documents for more detailed information.

This documentation only explains contract methods that are meant to be accessed directly. External methods that will revert unless called through another contract, such as IssuingEntity or modules, are not included.

It may be useful to also view the `SecurityToken.sol <https://github.com/SFT-Protocol/security-token/tree/master/contracts/SecurityToken.sol>`__ source code while reading this document.

Deployment
==========

The constructor takes the following arguments:

.. method:: SecurityToken.constructor(address _issuer, string _name, string _symbol, uint256 _authorizedSupply)

    * ``_issuer``: The address of the ``IssuingEntity`` associated with this token.
    * ``_name``: The full name of the token.
    * ``_symbol``: The ticker symbol for the token.
    * ``_authorizedSupply``: The initial authorized token supply.

    After the contract is deployed it must be associated with the issuer via ``IssuingEntity.addToken``. Token transfers are not possible until this is done.

    At the time of deployment the initial authorized supply is set, and the total supply is left as 0. The issuer may then mint tokens by calling ``modifyTotalSupply`` directly or via a module. See :ref:`security-token-mint-burn`.

Constants
=========

The following public variables cannot be changed after contract deployment.

.. method:: SecurityToken.name

    The full name of the security token.

.. method:: SecurityToken.symbol

    The ticker symbol for the token.

.. method:: SecurityToken.decimals

    The number of decimal places for the token. This is a constant always set to 0, as you cannot legally fractionalize a security.

.. method:: SecurityToken.ownerID

    The bytes32 ID hash of the issuer associated with this token.

.. method:: SecurityToken.issuer

    The address of the associated IssuingEntity contract.

Token Supply and Balances
=========================

Along with the standard ERC20 methods, SecurityToken introduces three additional methods around the total supply.



.. method:: SecurityToken.balanceOf(address)

    Returns the token balance for a given address.

.. method:: SecurityToken.treasurySupply

    Returns the number of tokens held by the issuer. Equivalent to calling ``SecurityToken.balanceOf(SecurityToken.ownerID())``.

.. method:: SecurityToken.circulatingSupply

    Returns the total supply, less the amount held by the issuer.

.. _security-token-mint-burn:

Token Supply, Minting and Burning
=================================

Along with the ERC20 standard ``totalSupply``, SecurityToken contracts include an ``authorizedSupply`` that represents the maximum allowable total supply. The issuer may mint new tokens using ``modifyTotalSupply`` until the total supply is equal to the authorized supply. The initial authorized supply is set during deployment and may be increased later using ``modifyAuthorizedSupply``.

A governance module can be used to dictate when the issuer is allowed to modify the authorized supply.

.. method:: SecurityToken.totalSupply

    Returns the current total supply of tokens.

.. method:: SecurityToken.authorizedSupply

    Returns the maximum authorized total supply of tokens. Whenever the authorized supply exceeds the total supply, the issuer may mint new tokens using ``modifyTotalSupply``.

.. method:: SecurityToken.modifyTotalSupply(address _owner, uint256 _value)

    Modifies the balance of a token holder, affecting the total supply.

    * ``_owner``: The account balance to modify.
    * ``_value``: The new balance of the account.

    If the current account balance is less than the new balance, tokens will be minted by transferring from ``0x00`` and the total supply will increase. The new total supply cannot exceed ``authorizedSupply``.

    If the current account balance is greater than the new balance, tokens will be burned by transferring to ``0x00`` and the total supply will decrease.

    This method is callable directly by the issuer, implementing multi-sig via ``MultiSig.checkMultiSigExternal``. It may also be called by a permitted module.

    Modules can hook into this method via ``STModule.totalSupplyChanged``. The modules are called after the total supply has has been changed.

.. method:: SecurityToken.modifyAuthorizedSupply(uint256 _value)

    Sets the authorized supply. The value may never be less than the current total supply.

    This method is callable directly by the issuer, implementing multi-sig via ``MultiSig.checkMultiSigExternal``. It may also be called by a permitted module.

    Modules can hook into this method via ``STModule.modifyAuthorizedSupply``. The modules are called before the authorized supply is changed.

Token Transfers
===============

SecurityToken uses the standard ERC20 methods for token transfers, however their functionality differs slightly due to transfer permissioning requirements.

.. method:: SecurityToken.checkTransfer(address _from, address _to, uint256 _value)

    Returns true if ``_from`` is permitted to transfer ``_value`` tokens to ``_to``.

    For a transfer to succeed it must first pass a series of checks:

    * Tokens cannot be locked.
    * Sender must have a sufficient balance.
    * Sender and receiver must be verified in a registrar associated to the issuer.
    * Sender and receiver must not be restricted by the registrar or the issuer.
    * Transfer must not result in any issuer-imposed investor limits being exceeded.
    * Transfer must be permitted by all active modules.

    Transfers between two addresses that are associated to the same ID do not undergo the same level of restrictions, as there is no change of ownership occuring.

    Modules can hook into this method via ``STModule.checkTransfer``.

.. method:: SecurityToken.transfer(address _to, uint256 _value)

    Transfers ``_value`` tokens from ``msg.sender`` to ``_to``.

    All transfers will log the ``Transfer`` event. Transfers where there is a change of ownership will also log``IssuingEntity.TransferOwnership``.

.. method:: SecurityToken.approve(address _spender, uint256 _value)

    Approves ``_spender`` to transfer up to ``_value`` tokens belonging to ``msg.sender``.

    Approval may be given to any address, but a transfer can only be initiated by an address that is known by one of the associated registrars. The same transfer checks also apply for both the sender and receiver, as if the transfer was done directly.

.. method:: SecurityToken.transferFrom(address _from, address _to, uint256 _value)

    Transfers ``_value`` tokens from ``_from`` to ``_to``.

    If the caller and sender addresses are both associated to the same ID, ``transferFrom`` may be called without giving prior approval. In this way an investor can easily recover tokens when a private key is lost or compromised.

    Modules can hook into this method via ``STModule.transferTokens``.

Issuer Balances and Transfers
=============================

Tokens held by the issuer will always be at the address of the IssuingEntity contract.  ``SecurityToken.treasurySupply()`` will return the same result as ``SecurityToken.balanceOf(SecurityToken.issuer())``.

As a result, the following non-standard behaviours exist:

* Any address associated with the issuer can transfer tokens from the IssuingEntity contract using ``SecurityToken.transfer``.
* Attempting to send tokens to any address associated with the issuer will result in the tokens being sent to the IssuingEntity contract.

The issuer may call ``SecurityToken.transferFrom`` to move tokens between any addresses without prior approval. Transfers of this type must still pass the normal checks, with the exception that the sending address may be restricted.  In this way the issuer can aid investors with token recovery in the event of a lost or compromised private key, or force a transfer in the event of a court order or sanction.

Modules
=======

Modules are attached and detached to token contracts via :ref:`issuing-entity`.

.. method:: SecurityToken.isActiveModule(address _module)

    Returns true if a module is currently active on the token.  Modules that are active on the IssuingEntity are also considered active on tokens.
