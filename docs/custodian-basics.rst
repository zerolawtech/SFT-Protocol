.. _custodian-basics:

###################
How Custodians Work
###################

Custody and Beneficial Ownership
================================

Custodians interact with an issuer’s investor counts differently from regular investors. When an investor transfers a balance into a custodian it does not increase the overall investor count, instead the investor is now included in the list of beneficial owners represented by the custodian. Even if the investor now has a balance of 0 in their own wallet, they will be still be included in the issuer’s investor count.

Custodian balances are tracked directly in the corresponding token contract and can be queried through ``TokenBase.custodianBalanceOf``.

.. code-block:: python

    >>> cust
    <OwnedCustodian Contract object '0x3BcC6Ad6CFbB1997eb9DA056946FC38a6b5E270D'>
    >>> token.balanceOf(accounts[1])
    10000
    >>> token.custodianBalanceOf(accounts[1], cust)
    0
    >>> token.balanceOf(cust)
    0
    >>> token.transfer(cust, 5000, {'from': accounts[1]})

    Transaction sent: 0x4b09b29216d130dc06798ee673759a4e77e4823655c6477e895242f027726412
    SecurityToken.transfer confirmed - block: 16   gas used: 155761 (1.95%)
    <Transaction object '0x4b09b29216d130dc06798ee673759a4e77e4823655c6477e895242f027726412'>
    >>> token.balanceOf(accounts[1])
    5000
    >>> token.custodianBalanceOf(accounts[1], cust)
    5000
    >>> token.balanceOf(cust)
    5000


Token Transfers
===============

There are three types of token transfers related to Custodians.

* **Inbound**: transfers from an investor into the Custodian contract.
* **Outbound**: transfers out of the Custodian contract to an investor's wallet.
* **Internal**: transfers involving a change of ownership within the Custodian contract. This is the only type of transfer that involves a change of ownership of the token, however no tokens actually move.

In order to perform these transfers, Custodian contracts interact with IssuingEntity and SecurityToken contracts via the following methods. None of these methods are user-facing; if you are only using the standard Custodian contracts within the protocol you can skip the rest of this section.

Inbound
-------

Inbound transfers are those where an investor sends tokens into the Custodian contract. They are initiated in the same way as any other transfer, by calling the ``SecurityToken.transfer`` or ``SecurityToken.transferFrom`` methods. Inbound transfers do not register a change of beneficial ownership, however if the sender previously had a 0 balance with the custodian they will be added to that custodian's list of beneficial owners.

During an inbound transfer the following method is be called in the custodian contract:

.. method:: IMiniCustodian.receiveTransfer(address _token, bytes32 _id, uint256 _value)

    * ``_token``: Token addresss being transferred to the the Custodian.
    * ``_id``: Sender ID.
    * ``_value``: Amount being transferred.

    Called from ``IssuingEntity.transferTokens``. Used to update the custodian's balance and investor counts. Revert or return ``false`` to block the transfer.

Outbound
--------

Outbound transfers are those where tokens are sent from the Custodian contract to an investor's wallet. Depending on the type of custodian and intended use case they may be initiated in several different ways.

Internally, the Custodian contract sends tokens back to an investor using the normal ``SecurityToken.transfer`` method. No change of beneficial ownership is recorded.

Internal
--------

Internal transfers involve a change of beneficial ownership records within the Custodian contract. Tokens do not enter or leave the Custodian contract, but a call is made to the corresponding token contract to verify that the transfer is permitted.

The Custodian contract can call the following token methods relating to  internal transfers.

.. method:: TokenBase.checkTransferCustodian(address _cust, address _from, address _to, uint256 _value)

    Checks if a custodian internal transfer of tokens is permitted.

    * ``_cust``: Address of the custodian
    * ``_from``: Address of the sender
    * ``_to``: Address of the recipient
    * ``_value``: Amount of tokens to be transferred

    Returns ``true`` if the transfer is permitted. If the transfer is not permitted, the call will revert with the reason given in the error string.

    Permissioning checks for custodial transfers are identical to those of normal transfers.

.. method:: SecurityToken.transferCustodian(address[2] _addr, uint256 _value)

    Modifies investor counts and ownership records based on an internal transfer of ownership within the Custodian contract.

    * ``_addr``: Array of sender and receiver addresses.
    * ``_value``: Amount of tokens being transferred


Minimal Implementation
======================

The `IBaseCustodian <https://github.com/HyperLink-Technology/SFT-Protocol/blob/master/contracts/interfaces/IBaseCustodian.sol>`__ interface defines a minimal implementation required for custodian contracts to interact with an IssuingEntity contract. Notably absent from this interface are methods for internal custodian transfers, or to transfer out of the contract. Depending on the type of custodian and intended use case, outgoing transfers may be implemented in different ways.

.. method:: IBaseCustodian.ownerID()

    Public bytes32 hash representing the owner of the contract.

.. method:: IBaseCustodian.receiveTransfer(address _token, bytes32 _id, uint256 _value)

    * ``_token``: Token addresss being transferred to the the Custodian.
    * ``_id``: Sender ID.
    * ``_value``: Amount being transferred.

    Called from ``IssuingEntity.transferTokens`` when tokens are being sent into the Custodian contract. It should be used to update the custodian's balance and investor counts. Revert or return ``false`` to block the transfer.
