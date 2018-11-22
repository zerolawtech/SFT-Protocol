.. _custodian:

#########
Custodian
#########

Custodian contracts allow approved entities to hold tokens on behalf of multiple investors. Common examples of custodians include broker/dealers and secondary markets.

Custodian contracts include the standard SFT protocol :ref:`multisig`.

It may be useful to also view the `Custodian.sol <https://github.com/SFT-Protocol/security-token/tree/master/contracts/Custodian.sol>`__ source code while reading this document.

Deployment
==========

The constructor declares the owner as per standard :ref:`multisig`.

.. method:: IssuingEntity.constructor(address[] _owners, uint32 _threshold)

    * ``_owners``: One or more addresses to associate with the contract owner. The address deploying the contract is not implicitly included within the owner list.
    * ``_threshold``: The number of calls required for the owner to perform a multi-sig action.

    The ID of the owner is generated as a keccak of the contract address and available from the public getter ``ownerID``.

Functionality
=============

Integration
===========

Old text
========

Custodians interact with an issuer's investor counts differently from regular investors. When an investor transfers a balance into the custodian it does not increase the overall investor count, instead the investor is now included in the list of beneficial owners represented by the custodian. Even if the investor now has a balance of 0, they will be still be included in the issuer's investor count.

Custodian contracts include a ``transfer`` function that optionally allows them to remove an investor from the beneficial owners when sending them tokens.

They may also call ``addInvestors`` or ``removeInvestors``   in cases where beneficial ownership has changed from an action happening off-chain.
Each custodian must be individually approved by an issuer before they can receive tokens. Because custodians may bypass on-chain compliance checks, it is imperative this approval only be given to known, trusted entities.
