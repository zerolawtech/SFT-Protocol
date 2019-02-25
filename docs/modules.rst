.. _modules:

#######
Modules
#######

Modules are contracts that hook into various methods in :ref:`issuing-entity`, :ref:`security-token` and :ref:`custodian` contracts. They may be used to add custom permissioning logic or extra functionality.

It may be useful to view source code for the following contracts while reading this document:

* `Modular.sol <https://github.com/SFT-Protocol/security-token/tree/master/contracts/components/Modular.sol>`__: Inherited by modular contracts. Provides functionality around attaching, detaching, and calling modules.
* `ModuleBase.sol <https://github.com/SFT-Protocol/security-token/tree/master/contracts/components/Modular.sol>`__: Inherited by modules. Provide required functionality for modules to be able to attach or detach.
* `IModules.sol <https://github.com/SFT-Protocol/security-token/tree/master/contracts/components/Modular.sol>`__: Interfaces outlining standard module functionality. Includes inputs for all possible hook methods.

.. note:: In order to minimize gas costs, modules should be attached only when their functionality is required and detached as soon as they are no longer needed.

.. warning:: Depending on the hook and permission settings, modules may be capable of actions such as blocking transfers, moving investor tokens and altering the total supply. Only attach a module that has been properly auditted, ensure you understand exactly what it does, and be **very** wary of any module that requires permissions outside of it's documented behaviour.

Attaching and Detaching
=======================

Modules are attached or detached via methods ``attachModule`` and ``detachModule`` in the inheriting contracts. See the :ref:`issuing-entity` and :ref:`custodian` documentation implementations.

Token modules are attached and detached via the associated IssuingEntity contract.

All contracts implementing modular functionality will also include the following method:

.. method:: Modular.isActiveModule(address _module)

    Returns true if a module is currently active on the contract.

    Modules that are attached to an IssuingEntity are also considered active on any tokens belonging to that issuer.

Modules include the following getters:

.. method:: ModuleBase.getOwner()

    Returns the address of the parent contract that the module has been attached to.

.. method:: ModuleBase.name()

    Returns a string name of the module.

Permissioning and Functionality
===============================

Modules introduce functionality in two ways:

* **Hooks** are points within the parent contract's methods where the module will be called. They can be used to introduce extra permissioning requirements or record additional data.
* **Permissions** are methods within the parent contract that the module is able to call into. This can allow actions such as adjusting investor limits, transferring tokens, or changing the total supply.

In short: hooks involve calls from a parent contract into a module, permissions involve calls from a module into the parent contract.

Hooks and permissions are set the first time a module is attached by calling the following method:

.. method:: ModuleBase.getPermissions()

    Returns two ``bytes4[]``:

    * ``hooks``: Array of method signatures within the module that the parent will call to.
    * ``permissions``: Array of method signatures within the parent contract that the module is permitted to call.

Before attaching a module, be sure to check the return value of this function and compare the requested hook points and permissions to those that would be required for the documented functionality of the module. For example, a module intended to block token transfers should not require permission to mint new tokens.

Hooking into Methods
====================

The available hook points varies depending on the type of parent contract.

SecurityToken
-------------

.. method:: STModule.checkTransfer(address[2] _addr, bytes32 _authID, bytes32[2] _id, uint8[2] _rating, uint16[2] _country, uint256 _value)

    * Hook signature: ``0x70aaf928``

    Called by ``SecurityToken.checkTransfer`` to verify if a transfer is permitted.

    * ``_addr``: Sender and receiver addresses.
    * ``_authID``: ID of the authority who wishes to perform the transfer. It may differ from the sender ID if the check is being performed prior to a ``transferFrom`` call.
    * ``_id``: Sender and receiver IDs.
    * ``_rating``: Sender and receiver investor ratings.
    * ``_country``: Sender and receiver countriy codes.
    * ``_value``: Amount to be transferred.

.. method:: STModule.transferTokens(address[2] _addr, bytes32[2] _id, uint8[2] _rating, uint16[2] _country, uint256 _value)

    * Hook signature: ``0x35a341da``

    Called after a token transfer has completed successfully with ``SecurityToken.transfer`` or ``SecurityToken.transferFrom``.

    * ``_addr``: Sender and receiver addresses.
    * ``_id``: Sender and receiver IDs.
    * ``_rating``: Sender and receiver investor ratings.
    * ``_country``: Sender and receiver country codes.
    * ``_value``: Amount that was transferred.

.. method:: STModule.transferTokensCustodian(address _custodian, bytes32[2] _id, uint8[2] _rating, uint16[2] _country, uint256 _value)

    * Hook signature: ``0x6eaf832c``

    Called after an internal custodian token transfer has completed with ``Custodian.transferInternal``.

    * ``_custodian``: Address of the custodian contract.
    * ``_id``: Sender and receiver IDs.
    * ``_rating``: Sender and receiver investor ratings.
    * ``_country``: Sender and receiver country codes.
    * ``_value``: Amount that was transferred.

.. method:: STModule.totalSupplyChanged(address _addr, bytes32 _id, uint8 _rating, uint16 _country, uint256 _old, uint256 _new)

    * Hook signature: ``0x741b5078``

    Called after the total supply has been modified by ``SecurityToken.modifyTotalSupply``.

    * ``_addr``: Address where balance has changed.
    * ``_id``: ID that the address is associated to.
    * ``_rating``: Investor rating.
    * ``_country``: Investor country code.
    * ``_old``: Previous token balance at the address.
    * ``_new``: New token balance at the address.

.. method:: STModule.modifyAuthorizedSupply(address _token, uint256 _oldSupply, uint256 _newSupply)

    * Hook signature: ``0xb1a1a455``

    Called before changing the authorized supply of a token.

    * ``_token``: Token address
    * ``_oldSupply``: Current authorized supply
    * ``_newSupply``: New authorized supply

IssuingEntity
-------------

.. method:: IssuerModule.checkTransfer(address _token, bytes32 _authID, bytes32[2] _id, uint8[2] _rating, uint16[2] _country, uint256 _value)

    * Hook signature: ``0x47fca5df``

    Called by ``IssuingEntity.checkTransfer`` to verify if a transfer is permitted.

    * ``_token``: Address of the token to be transferred.
    * ``_authID``: ID of the authority who wishes to perform the transfer. It may differ from the sender ID if the check is being performed prior to a ``transferFrom`` call.
    * ``_id``: Sender and receiver IDs.
    * ``_rating``: Sender and receiver investor ratings.
    * ``_country``: Sender and receiver countriy codes.
    * ``_value``: Amount to be transferred.

.. method:: IssuerModule.transferTokens(address _token, bytes32[2] _id, uint8[2] _rating, uint16[2] _country, uint256 _value)

    * Hook signature: ``0x0cfb54c9``

    Called after a token transfer has completed successfully with ``SecurityToken.transfer`` or ``SecurityToken.transferFrom``.

    * ``_token``: Address of the token that was transferred.
    * ``_id``: Sender and receiver IDs.
    * ``_rating``: Sender and receiver investor ratings.
    * ``_country``: Sender and receiver country codes.
    * ``_value``: Amount that was transferred.

.. method:: IssuerModule.transferTokensCustodian(address _token, address _custodian, bytes32[2] _id, uint8[2] _rating, uint16[2] _country, uint256 _value)

    * Hook signature: ``0x3b59c439``

    Called after an internal custodian token transfer has completed with ``Custodian.transferInternal``.

    * ``_token``: Address of the token that was transferred.
    * ``_custodian``: Address of the custodian contract.
    * ``_id``: Sender and receiver IDs.
    * ``_rating``: Sender and receiver investor ratings.
    * ``_country``: Sender and receiver country codes.
    * ``_value``: Amount that was transferred.

.. method:: IssuerModule.tokenTotalSupplyChanged(address _token, bytes32 _id, uint8 _rating, uint16 _country, uint256 _old, uint256 _new)

    * Hook signature: ``0xb446f3ca``

    Called after a token's total supply has been modified by ``SecurityToken.modifyTotalSupply``.

    * ``_token``: Token address where balance has changed.
    * ``_id``: ID of the investor who's balance changed.
    * ``_rating``: Investor rating.
    * ``_country``: Investor country code.
    * ``_old``: Previous investor balance (across all tokens).
    * ``_new``: New investor balance (across all tokens).

Custodian
---------

.. method:: CustodianModule.sentTokens(address _token, bytes32 _id, uint256 _value, bool _stillOwner)

    * Hook signature: ``0x31b45d35``

    Called after tokens have been transferred out of a Custodian via ``Custodian.transfer``.

    * ``_token``: Address of token that was sent.
    * ``_id``: ID of the recipient.
    * ``_value``: Number of tokens that were sent.
    * ``_stillOwner``: Is the recipient still a beneficial owner for this token?

.. method:: CustodianModule.receivedTokens(address _token, bytes32 _id, uint256 _value, bool _newOwner)

    * Hook signature: ``0xa0e7f751``

    Called after a tokens have been transferred into a Custodian.

    * ``_token``: Address of token that was received.
    * ``_id``: ID of the sender.
    * ``_value``: Number of tokens that were received.

.. method:: CustodianModule.internalTransfer(address _token, bytes32 _fromID, bytes32 _toID, uint256 _value, bool _stillOwner)

    * Hook signature: ``0x7054b724``

    Called after an internal transfer of ownership within the Custodian contract via ``Custodian.transferInternal``.

    * ``_token``: Address of token that was received.
    * ``_fromID``: ID of the sender.
    * ``_toID``: ID of the recipient.
    * ``_value``: Number of tokens that were received.
    * ``_stillOwner``: Is the sender still a beneficial owner for this token?

.. method:: CustodianModule.ownershipReleased(address _issuer, bytes32 _id)

    * Hook signature: ``0x054d1c76``

    Called after an investor's beneficial ownership status has been released within the Custodian contract via ``Custodian.releaseOwnership``.

    * ``_issuer``: IssuingEntity contract address
    * ``_id``: Investor ID

Calling Parent Methods
======================

Once attached, modules may call into methods in the parent contract where they have been given permission.

.. note:: When a module calls into the parent contract, it will still trigger any of it's own methods hooked into the called method. With poor contract design you can create infinite loops and effectively break the parent contract functionality as long as the module remains attached.

SecurityToken
-------------

Any module applied to an IssuingEntity contract may also be permitted to call methods on any token belonging to the issuer.  See :ref:`security-token` for more detailed information on these methods.

.. method:: SecurityToken.transferFrom(address _from, address _to, uint256 _value)

    * Permission signature: ``0x23b872dd``

    Transfers tokens between two addresses. A module calling ``transferFrom`` has the same level of authority as if the call was from the issuer.

    Calling this method will also call any hooked in ``checkTransfer`` and ``transferTokens`` methods.

.. method:: SecurityToken.modifyBalance(address _owner, uint256 _value)

    * Permission signature: ``0x250dea06``

    Sets the balance of ``_owner`` to ``_value`` and modifies ``totalSupply`` accordingly. This method is only callable by a module.

    Calling this method will also call any hooked in ``balanceChanged`` methods.

.. method:: SecurityToken.detachModule(address _module)

    * Permission signature: ``0xbb2a8522``

    Detaches a module. This method can only be called directly by a permitted module, for the issuer to detach a SecurityToken level module the call must be made via the IssuingEntity contract.

IssuingEntity
-------------

.. method:: IssuingEntity.detachModule(address _target, address _module)

    * Permission signature: ``0xbb2a8522``

    Detaches module contract ``_module`` from parent contract ``_target``.

Custodian
---------

See :ref:`custodian` for more detailed information on these methods.

.. method:: Custodian.transfer(address _token, address _to, uint256 _value, bool _stillOwner)

    * Permission signature: ``0x75219e4e``

    Transfers tokens from the custodian to an investor.

    Calling this method will also call any hooked in ``sentTokens`` methods.

.. method:: Custodian.transferInternal(address _token, bytes32 _fromID, bytes32 _toID, uint256 _value, bool _stillOwner)

    * Permission signature: ``0x2965c868``

    Transfers the ownership of tokens between investors within the Custodian contract.

    Calling this method will also call any hooked in ``internalTransfer`` methods.

.. method:: Custodian.releaseOwnership(address _issuer, bytes32 _id)

    * Permission signature: ``0xc07f6f8e``

    Removes an investor from the Custodian's list of beneficial owners.

    Calling this method will also call any hooked in ``ownershipReleased`` methods.

.. method:: Custodian.detachModule(address _module)

    * Permission signature: ``0xbb2a8522``

    Detaches a module.

Use Cases
=========

The wide range of functionality that modules can hook into and access allows for many different applications. Some examples include: crowdsales, country/time based token locks, right of first refusal enforcement, voting rights, dividend payments, tender offers, and bond redemption.

We have included some sample modules on `GitHub <https://github.com/SFT-Protocol/security-token/tree/master/contracts/modules>`__ as examples to help understand module development and demonstrate the range of available functionality.
