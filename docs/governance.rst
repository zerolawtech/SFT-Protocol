.. _governance:

##########
Governance
##########

The ``Goveranance`` contract is a special type of module that may optionally be attached to an :ref:`issuing-entity`.  It is used to add on-chain voting functionality for token holders.  When attached, it adds a permissioning check before increasing authorized token supplies or adding new tokens.

SFT includes a very minimal proof of concept as a starting point for developing a governance contract. It can be combined with a checkpoint module to build whatever specific setup is required by an issuer.

It may be useful to view source code for the following contracts while reading this document:

* `Governance.sol <https://github.com/HyperLink-Technology/SFT-Protocol/blob/master/contracts/modules/Governance.sol>`__: A minimal implementation of ``Goverance``, intended for testing purposes or as a base for building a functional contract.
* `IGovernance.sol <https://github.com/HyperLink-Technology/SFT-Protocol/blob/master/contracts/interfaces/IGovernance.sol>`__: The minimum contract interface required for a governance module to interact with an ``IssuingEntity`` contract.

Public Constants
================

.. method:: Governance.issuer()

    The address of the associated ``IssuingEntity`` contract.

    .. code-block:: python

        >>> governance.issuer()
        0x40b49Ad1B8D6A8Df6cEdB56081D51b69e6569e06

Checking Permissions
====================

The following methods must return ``true`` in order for the calling methods to execute.

.. method:: Governance.addToken(address _token)

    Called by ``IssuingEntity.addToken`` before associating a new token contract.

.. method:: Governance.modifyAuthorizedSupply(address _token, uint256 _value)

    Called by ``TokenBase.modifyAuthorizedSupply`` before modifying the authorized supply.
