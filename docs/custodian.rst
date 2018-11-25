.. _custodian:

#########
Custodian
#########

Custodian contracts allow approved entities to hold tokens on behalf of multiple investors. Common examples of custodians include broker/dealers and secondary markets.

Custodian contracts include the standard SFT protocol :ref:`multisig` and :ref:`modules` functionality. See the respective documents for detailed information on these components.

It may be useful to also view the `Custodian.sol <https://github.com/SFT-Protocol/security-token/tree/master/contracts/Custodian.sol>`__ source code while reading this document.

Deployment
==========

The constructor declares the owner as per standard :ref:`multisig`.

.. method:: Custodian.constructor(address[] _owners, uint32 _threshold)

    * ``_owners``: One or more addresses to associate with the contract owner. The address deploying the contract is not implicitly included within the owner list.
    * ``_threshold``: The number of calls required for the owner to perform a multi-sig action.

    The ID of the owner is generated as a keccak of the contract address and available from the public getter ``ownerID``.

Token Transfers
===============

To maintain accurate beneficial owner records, custodians must initiate all token transfers through the contract instead of calling ``SecurityToken.transfer`` directly.

.. method:: Custodian.transfer(address _token, address _to, uint256 _value, bool _stillOwner)

    Transfers tokens from the custodian.

    * ``_token``: Contract address of the token to transfer
    * ``_to``: Address of the recipient
    * ``_value``: Number of tokens to transfer
    * ``_stillOwner``: After this transfer, is the recipient still on the custodian's list of beneficial owners for this token?

    The ``_stillOwner`` boolean is only used to remove investors from the list of beneficial owners. If it is set to true but the recipient was not previously listed, they will not be added.

.. method:: Custodian.receiveTransfer(address _token, bytes32 _id, uint256 _value)

    Called by IssuingEntity when tokens are sent to a custodian.

    * ``_token``: Contract address of the token being received.
    * ``_id``: ID of the token sender
    * ``_value``: Number of tokens being transferred

    This method may be modified to introduce extra functionality according to the needs of the custodian.

Beneficial Owners
=================

Whenever a transfer happens on-chain, the custodian's beneficial owner list is updated:

    * When tokens are transfered to a custodian, the sender is added to the list of beneficial owners for that token.
    * When tokens are transfered from a custodian, the receipient may be removed from the list of beneficial owners by setting ``_stillOwner`` to false.

As one of the purposes of custodians is to facilitate off-chain transfers of ownership, they are also able to manually update their beneficial ownership records.

.. warning:: When adding a beneficial owner no checks are made against country restrictions, investor limits, or minimum investor ratings. It is the responsibility of the custodian to ensure compliance in any off-chain transfers of ownership.

.. method:: Custodian.addInvestors(address _token, bytes32[] _id)

    Adds beneficial owners to a token.

    * ``_token``: Contract address of the token to add benefical owners to.
    * ``_id``: Array of investor IDs.

.. method:: Custodian.removeInvestors(address _token, bytes32[] _id)

    Removes beneficial owners from a token.

    * ``_token``: Contract address of the token to remove benefical owners from.
    * ``_id``: Array of investor IDs.

.. _custodian-modules:

Modules
=======

.. method:: Custodian.attachModule(address _module)

    Attaches a module.

.. method:: Custodian.detachModule(address _module)

    Detaches a module. A module may call to detach itself but not other modules.

.. method:: Custodian.isActiveModule(address _module)

     Returns true if a module is currently active on the contract.

