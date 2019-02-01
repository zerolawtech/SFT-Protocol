.. _custodian:

#########
Custodian
#########

Custodian contracts allow approved entities to hold tokens on behalf of multiple investors. Each custodian must be individually approved by an issuer before they can receive tokens.

There are two broad categories of custodians:

* **Owned** custodians are contracts that are controlled and maintained by a known legal entity. Examples of owned custodians include broker/dealers or centralized exchanges.
* **Autonomous** custodians are contracts without an owner. Once deployed there is no authority capable of exercising control over the contract. Examples of autonomous custodians include escrow services, privacy protocols and decentralized exchanges.

It may be useful to view source code for the following contracts while reading this document:

* `IMiniCustodian.sol <https://github.com/SFT-Protocol/security-token/blob/master/contracts/interfaces/IMiniCustodian.sol>`__: The minimum contract interface required for a Custodian contract to interact with an IssuingEntity contract.
* `Owned.sol <https://github.com/SFT-Protocol/security-token/blob/master/contracts/custodians/Owned.sol>`__: Standard owned custodian contract with Multisig and Modular functionality.
* `Escrow.sol <https://github.com/SFT-Protocol/security-token/blob/master/contracts/custodians/Escrow.sol>`__: An example autonomous custodian implementation, providing on-chain enforceable escrow.

.. warning:: An issuer should not approve a Custodian contract if it's source code cannot be verified, or it is using a non-standard implementation that has not undergone a thorough audit. Inaccurate balance reporting could enable a range of exploits. The SFT protocol includes a standard owned Custodian contract that allows for modular customization without introducing security concerns.

How Custodians Work
===================

Custody and Beneficial Ownership
--------------------------------

Custodians interact with an issuer’s investor counts differently from regular investors. When an investor transfers a balance into a custodian it does not increase the overall investor count, instead the investor is now included in the list of beneficial owners represented by the custodian. Even if the investor now has a balance of 0 in their own wallet, they will be still be included in the issuer’s investor count.

Custodian transfer functions include a boolean ``_stillOwner``. When set to true, even if an investor's balance is at 0 as a result of a transfer, that investor will still be included in the list of beneficial owners within the custodian. This allows the custodian to continue to reserver the slot within the investor count, which is useful in a situation such as a secondary market where an investor may be moving in and out of the position many times over a short period.

The value of ``_stillOwner`` is only checked when a transfer results in a 0 balance for the sender. If set to false during a transfer where the investor's final balance is greater than zero, the transfer will succeed but the beneficial owner status will not be released.

Token Transfers
---------------

There are three types of token transfers related to Custodians.

* **Inbound**: transfers from an investor into the Custodian contract.
* **Outbound**: transfers from the Custodian contract to an investor's wallet.
* **Internal**: transfers involving a change of beneficial ownership records within the Custodian contract. This is the only type of transfer that involves a change of ownership of the token.

In order to perform these transfers, Custodian contracts interact with IssuingEntity and SecurityToken contracts via the following methods. None of these methods are user-facing; if you are only using the standard Custodian contracts within the protocol you can skip the rest of this section.

Inbound
*******

Inbound transfers are those where an investor sends tokens into the Custodian contract. They are initiated in the same way as any other transfer, by calling the ``SecurityToken.transfer`` or ``SecurityToken.transferFrom`` methods. Inbound transfers do not register a change of beneficial ownership, however if the sender previously had a 0 balance with the custodian they will be added to that custodian's list of beneficial owners.

During an inbound transfer the following method is be called in the custodian contract:

.. method:: IMiniCustodian.receiveTransfer(address _token, bytes32 _id, uint256 _value)

    * ``_token``: Token addresss being transferred to the the Custodian.
    * ``_id``: Sender ID.
    * ``_value``: Amount being transferred.

    Called from ``IssuingEntity.transferTokens``. Used to update the custodian's balance and investor counts. Revert or return ``false`` to block the transfer.

Outbound
********

Outbound transfers are those where tokens are sent from the Custodian contract to an investor's wallet. Depending on the type of custodian and intended use case they may be initiated in several different ways.

Internally, the Custodian contract sends tokens back to an investor using the normal ``SecurityToken.transfer`` method. No change of beneficial ownership is recorded.

The IssuingEntity contract does not keep a specific record of investor balances within each Custodian. If a transfer removes an investor from the Custodian's list of beneficial owners, it should be followed by a call to ``IssuingEntity.releaseOwnership``. See the :ref:`issuing-entity` documentation for information about this method.

Internal
********

Internal transfers involve a change of beneficial ownership records within the Custodian contract. Tokens do not enter or leave the Custodian contract, but a call is made to the corresponding token contract to verify that the transfer is permitted.

The Custodian contract can call the following SecurityToken methods to register internal transfers.

.. method:: SecurityToken.checkTransferCustodian(bytes32[2] _id, bool _stillOwner)

    Returns true if the Custodian is permitted to perform an internal transfer of ownership for this token.

    * ``_id``: Array of sender and recipient IDs.
    * ``_stillOwner``: Is the sender still a beneficial owner?

.. method:: SecurityToken.transferCustodian(bytes32[2] _id, uint256 _value, bool _stillOwner)

    Modifies investor counts and ownership records based on an internal transfer of ownership within the Custodian contract.

    * ``_id``: Array of sender and recipient IDs.
    * ``_value``: Amount of tokens being transferred
    * ``_stillOwner``: Is the sender still a beneficial owner?


Minimal Implementation
----------------------

The ``IMiniCustodian`` interface defines a minimal implementation required for custodian contracts to interact with an IssuingEntity contract. Notably absent from this interface is a way for tokens to transfer out of the contract. Depending on the type of custodian and intended use case, outgoing transfers may be implemented in different ways.

.. method:: IMiniCustodian.ownerID()

    Public bytes32 hash representing the owner of the contract.

.. method:: IMiniCustodian.balanceOf(address _token, bytes32 _id)

    View function to query the balance of an investor for a specific token.

    * ``_token``: SecurityToken address
    * ``_id``: Investor ID

    While there is no strict requirement for a Custodian to maintain an on-chain record of investor balances, this information is necessary if the custodian is to e.g. allow investors to claim dividends or exercise voting rights based on held balances. As such, balances should always be accurately recorded on-chain unless there is a use case that requires otherwise.

.. method:: IMiniCustodian.isBeneficialOwner(address _issuer, bytes32 _id)

    Checks if an investor is on the custodian's list of beneficial owners for this issuer.

    * ``_issuer``: IssuingEntity contract address
    * ``_id``: Investor ID

.. method:: IMiniCustodian.receiveTransfer(address _token, bytes32 _id, uint256 _value)

    * ``_token``: Token addresss being transferred to the the Custodian.
    * ``_id``: Sender ID.
    * ``_value``: Amount being transferred.

    Called from ``IssuingEntity.transferTokens`` when tokens are being sent into the Custodian contract. It should be used to update the custodian's balance and investor counts. Revert or return ``false`` to block the transfer.

Owned Custodians
================

Owned custodians are contracts that are controlled and maintained by a known legal entity. Examples of owned custodians include broker/dealers or centralized exchanges.

Owned Custodian contracts include the standard SFT protocol :ref:`multisig` and :ref:`modules` functionality. See the respective documents for detailed information on these components.

Deployment
----------

The constructor declares the owner as per standard :ref:`multisig`.

.. method:: OwnedCustodian.constructor(address[] _owners, uint32 _threshold)

    * ``_owners``: One or more addresses to associate with the contract owner. The address deploying the contract is not implicitly included within the owner list.
    * ``_threshold``: The number of calls required for the owner to perform a multi-sig action.

    The ID of the owner is generated as a keccak of the contract address and available from the public getter ``ownerID``.

Token Transfers
---------------

Investor balances for each token are tracked on-chain. Investors may send tokens into the contract, but only the contract owner has the authority to initiate internal and outbound transfers.

To maintain accurate beneficial owner records, custodians must initiate all token transfers through the contract instead of calling ``SecurityToken.transfer`` directly.

.. method:: OwnedCustodian.checkTransferInternal(address _token, bytes32 _fromID, bytes32 _toID, uint256 _value, bool _stillOwner)

    Checks if an internal transfer is permitted.

    * ``_token``: SecurityToken address
    * ``_fromID``: Sender ID
    * ``_toID``: Receiver ID
    * ``_value``: Amount to transfer
    * ``_stillOwner``: Is the sender still a beneficial owner for this issuer?

.. method:: OwnedCustodian.transferInternal(address _token, bytes32 _fromID, bytes32 _toID, uint256 _value, bool _stillOwner)

    * ``_token``: SecurityToken address
    * ``_fromID``: Sender ID
    * ``_toID``: Receiver ID
    * ``_value``: Amount to transfer
    * ``_stillOwner``: Is the sender still a beneficial owner for this issuer?

.. method:: OwnedCustodian.transfer(address _token, address _to, uint256 _value, bool _stillOwner)

    Transfers tokens out of the Custodian contract.

    * ``_token``: SecurityToken address
    * ``_to``: Investor address to send tokens to
    * ``_value``: Amount to transfer
    * ``_stillOwner``: Is the receiver still a beneficial owner for this issuer?

.. _custodian-modules:

Modules
-------

See the :ref:`modules` documentation for information module funtionality and development.

.. note:: For Custodians that require bespoke functionality it is preferrable to attach modules than to modify the core contract. Inaccurate balance reporting could enable a range of exploits, and so Issuers should be very wary of permitting any Custodian that uses a non-standard contract.

.. method:: OwnedCustodian.attachModule(address _module)

    Attaches a module to the custodian.

.. method:: OwnedCustodian.detachModule(address _module)

    Detaches a module. A module may call to detach itself, but not other modules.

.. method:: OwnedCustodian.isActiveModule(address _module)

     Returns true if a module is currently active on the contract.

Autonomous Custodians
=====================

Autonomous custodians have no owner. Once deployed there is no authority capable of exercising control over the contract. Examples of autonomous custodians include escrow services, privacy protocols and decentralized exchanges.

Unlike the owned Custodian there is no single common approach for an autonomous custodian. Their use cases vary significantly such that we cannot effectively define a standard interface.

At present SFT contains one autonomous Custodian, an on-chain escrow contract meant to serve as a proof of concept. We intend to develop and audit additional autonomous Custodian contracts to expand the range of functionality in the protocol.
