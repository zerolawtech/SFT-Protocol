.. _security-considerations:

#######################
Security Considerations
#######################

A fully realized implementation of the SFT protocol involves many interconnected contracts maintained by different entities. As such, it is important to anticipate and prepare actions plans for events where another party is compromised or found to be a bad actor.

We have compiled a list of possible scenarios and solutions below. If you can imagine an issue that is not mentioned here, please contact us so we can discuss it and add it to the list.

Investor Changes Country
========================

An investor who changes their legal country of residence will necessarily alter their ID hash. In this case the investor should resubmit their KYC/AML to an authority within the new country, receive a new ID hash attached to a new address, and transfer their tokens from their old address to the new one. Their old ID may then be restricted.

Lost Investor Private Key
=========================

An investor who has lost a private key should contact the registry authority and verify their identity off-chain. The authority can then restrict the address of the lost key and add one or more new addresses that the investor controls. The investor may retrieve tokens from the lost address either with assistance from the issuer or by using the ``SecurityToken.transferFrom`` function. See the :ref:`security-token` documentation for more information on this process.

Compromised Authority
=====================

If an authority has been compromised or found to be acting in bad faith, the owner may apply a broad restriction upon them using ``setAuthorityRestriction``. This will also restrict every investor that was approved by this authority.

A list of investors that were approved by the restricted authority can be obtained from ``NewInvestor`` and ``UpdatedInvestor`` events. Once the KYC/AML of these investors has been re-verified, the restriction upon them may be removed by calling either ``updateInvestor`` or ``setInvestorAuthority``.

Compromised Owner
=================

If the owner is compromised or found to be acting in bad faith, issuers can remove the registrar by calling ``IssuingEntity.setRegistrar``. This will also restrict every investor that was approved by this registry. These investors will have to KYC via a different authority in order to be able to transfer their tokens.
