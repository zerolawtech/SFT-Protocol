.. _modules:

#######
Modules
#######

Modules are contracts that hook into various methods in :ref:`issuing-entity`, :ref:`security-token` and :ref:`custodian` contracts to provided added functionality. They may be used to add custom permissioning logic or extra functionality.

It may be useful to view source code for the following contracts while reading this document:

* `Modular.sol <https://github.com/SFT-Protocol/security-token/tree/master/contracts/components/Modular.sol>`__: Inherited by modular contracts. Provides functionality around attaching, detaching, and calling modules.
* `ModuleBase.sol <https://github.com/SFT-Protocol/security-token/tree/master/contracts/components/Modular.sol>`__: Inherited by modules. Provide required functionality for modules to be able to attach or detach.
* `IModules.sol <https://github.com/SFT-Protocol/security-token/tree/master/contracts/components/Modular.sol>`__: Interfaces outlining standard module functionality. Includes inputs for all possible hook methods.

.. note:: In order to minimize gas costs, modules should be attached only when their functionality is required and detached as soon as they are no longer needed.

.. warning:: Modules have a high level of permission and are capable of actions such as token transfers and altering the total supply. Only attach a module that has been properly auditted and ensure you understand exactly what it does.

Attaching and Detaching
=======================

Modules are attached or detached via methods ``attachModule`` and ``detachModule`` in the inheriting contracts. See the :ref:`issuing-entity` and :ref:`custodian` documentation implementations.

Hooking into Methods
====================

All modules must include the following getter method:

.. method:: Modular.getHooks()

    Returns a bytes4[] of function signatures the module is to be called at.

Modules hook into specific methods within the contract they are applied to by adding function signatures to the private bytes4[] ``hooks``.  This is done in the constructor, for example:

::

    constructor(address _owner) STModuleBase(_owner) public {
        /* other functionality */
        hooks.push(0x35a341da);
        hooks.push(0x4268353d);
    }

The signatures are those of methods within the module that should be called. They are unique depending on the type of contract the module will attach to.  Possible hook points and their corresponding methods include:

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
    * ``_value``: Amount to be transferred.

.. method:: STModule.balanceChanged(address _addr, bytes32 _id, uint8 _rating, uint16 _country, uint256 _old, uint256 _new)

    * Hook signature: ``0x4268353d``

    Called after a balance has been directly modified by ``SecurityToken.modifyBalance``. Calls to this method also modify the total supply.

    * ``_addr``: Address where balance has changed.
    * ``_id``: ID that the address is associated to.
    * ``_rating``: Investor rating.
    * ``_country``: Investor country code.
    * ``_old``: Previous token balance at the address.
    * ``_new``: New token balance at the address.


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
    * ``_value``: Amount to be transferred.

.. method:: IssuerModule.balanceChanged(address _token, bytes32 _id, uint8 _rating, uint16 _country, uint256 _old, uint256 _new)

    * Hook signature: ``0x4268353d``

    Called after a balance has been directly modified by ``SecurityToken.modifyBalance``. Calls to this method also modify the total supply.

    * ``_token``: Token address where balance has changed.
    * ``_id``: ID of the investor who's balance changed.
    * ``_rating``: Investor rating.
    * ``_country``: Investor country code.
    * ``_old``: Previous investor balance (across all tokens).
    * ``_new``: New investor balance (across all tokens).

Custodian
---------

.. method:: CustodianModule.sentTokens(address _token, bytes32 _id, uint256 _value, bool _stillOwner)

    * Hook signature: ``0x7ffebabc``

    Called after a custodian has sent tokens.

    * ``_token``: Address of token that was transferred.
    * ``_id``: ID of the recipient.
    * ``_value``: Number of tokens that were transferred.
    * ``_stillOwner``: Is the recipient still a beneficial owner for this token?

.. method:: CustodianModule.receivedTokens(address _token, bytes32 _id, uint256 _value, bool _newOwner)

    * Hook signature: ``0x081e5f03``

    Called after a custodian has received tokens.

    * ``_token``: Address of token that was transferred.
    * ``_id``: ID of the sender.
    * ``_value``: Number of tokens that were transferred.
    * ``_stillOwner``: Is the sender a new beneficial owner for this token?

.. method:: CustodianModule.addedInvestors(address _token, bytes32[] _id)

    * Hook signature: ``0xf8324d5a``

    Called after a custodian has added one or more beneficial owners to a token.

    * ``_token``: Address of the token new owners are to be added to.
    * ``_id``: Array of added investor IDs. May contain 0x00 entries, these should be ignored.

.. method:: CustodianModule.removedInvestors(address _token, bytes32[] _id)

    * Hook signature: ``0x9898b82e``

    Called after a custodian has removed one or more beneficial owners from a token.

    * ``_token``: Address of the token new owners are to be removed from.
    * ``_id``: Array of removed investor IDs.  May contain 0x00 entries, these should be ignored.

Calling Parent Methods
======================

Once attached, modules are permitted to call certain methods in the parent contract.

.. note:: When a module calls into the parent contract, it will still trigger any of it's own methods hooked into the called method. With poor contract design you can create infinite loops and effectively break the parent contract functionality as long as the module is attached.

SecurityToken
-------------

Any module applied to an IssuingEntity contract may also call the following methods on any token belonging to that issuer.  See :ref:`security-token` for more detailed information on these methods.

.. method:: SecurityToken.transferFrom(address _from, address _to, uint256 _value)

    Transfers tokens between two addresses. A module calling ``transferFrom`` has the same level of authority as if the call was from the issuer.

    Calling this method will also call any hooked in ``checkTransfer`` and ``transferTokens`` methods.

.. method:: SecurityToken.modifyBalance(address _owner, uint256 _value)

    Sets the balance of ``_owner`` to ``_value`` and modifies ``totalSupply`` accordingly. This method is only callable by a module.

    Calling this method will also call any hooked in ``balanceChanged`` methods.

Custodian
---------

See :ref:`custodian` for more detailed information on these methods.

.. method:: Custodian.transfer(address _token, address _to, uint256 _value, bool _stillOwner)

    Transfers tokens from the custodian to an investor.

    Calling this method will also call any hooked in ``sentTokens`` methods.

.. method:: Custodian.addInvestors(address _token, bytes32[] _id)

    Adds investors to the list of beneficial owners for a token.

    Calling this method will also call any hooked in ``addedInvestors`` methods.

.. method:: Custodian.removeInvestors(address _token, bytes32[] _id)

    Removes investors from the list of beneficial owners for a token.

    Calling this method will also call any hooked in ``removedInvestors`` methods.

Use Cases
=========

The wide range of functionality that modules can hook into, combined with their high level of authority, allows for many different applications. Some examples include: crowdsales, country/time based token locks, right of first refusal enforcement, voting rights, dividend payments, tender offers, and bond redemption.

We have included some sample modules on `GitHub <https://github.com/SFT-Protocol/security-token/tree/master/contracts/modules>`__ as examples to help understand module development and demonstrate the range of available functionality.
