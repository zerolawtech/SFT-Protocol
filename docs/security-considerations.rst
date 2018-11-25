.. _security-considerations:

#######################
Security Considerations
#######################

A fully realized implementation of the SFT protocol involves many interconnected contracts maintained by different entities. As such, it is important to anticipate and know how to deal with events where another party is compromised or found to be acting in bad faith.

We have compiled a list of possible scenarios and solutions below. If you can imagine an issue that is not mentioned here, please contact us so we can discuss it and add it to the list.

.. note:: In this section we provide technical solutions to problems, however many of these situations will also have a legal component. The nature of security tokens means that every involved entity is easily identified, so when someone is acting in bad-faith it is possible that resolution will be the result of a court order. Issuers must keep in mind that although technically they can transfer any investor's tokens without approval, this does not mean that legally they are always allowed to.

Investor Changes Country
------------------------

An investor who changes their legal country of residence will necessarily alter their ID hash. In this case the investor should resubmit their KYC/AML to an registrar active within the new country, receive a new ID hash attached to a new address, and transfer their tokens from their old address to the new one. Their old ID may then be restricted.

Investor is Sanctioned
----------------------
If an investor is sanctioned or otherwise has their assets legally frozen, a registrar can use ``KYCRegistrar.setInvestorRestriction`` to block them from transferring any of their tokens.

Lost Investor Private Key
-------------------------

An investor who has lost a private key should contact the registry authority and verify their identity off-chain. The authority can restrict the address of the lost key with ``KYCRegistrar.restrictAddresses``, then add one or more new addresses with ``KYCRegistrar.registerAddresses``. The investor may retrieve tokens from the lost address either with assistance from the issuer, or by using the ``SecurityToken.transferFrom`` method.

Compromised Investor Private Key
--------------------------------

If an investor's private key is hacked, they should contract the registrar immediately to have the hacked address restricted. If tokens were transferred from the restricted address before it was blocked, the response will depend on the nature of the transfers:

* If tokens were sent directly to another investor, the issuer can use ``IssuingEntity.setInvestorRestriction`` to restrict the recipient until a legal resolution is reached. They can then use ``SecurityToken.transferFrom`` to return the tokens to the original address.

* If tokens were sent directly into a centralized exchange, the exchange must be notified immediately. Whether the exchange can help will depend on if the tokens were sold or not, and if yes, whether the funds from the sale were withdrawn and where they were sent.

Compromised Registrar Authority
-------------------------------

If a registrar authority has been hacked or found to be acting in bad faith, the owner of the registrar may apply a broad restriction upon them using ``setAuthorityRestriction``. This will also restrict every investor that was approved by this authority.

A list of investors that were approved by the restricted authority can be obtained from ``NewInvestor`` and ``UpdatedInvestor`` events. Once the KYC/AML of these investors has been re-verified, the restriction upon them may be removed by calling either ``KYCRegistrar.updateInvestor`` or ``KYCRegistrar.setInvestorAuthority``.

Compromised Registrar
---------------------

In a case where a registrar contract is so thoroughly compromised that an issuer deems it can no longer be trusted, the issuer can remove the registrar by calling ``IssuingEntity.setRegistrar``. This will also restrict every investor that was approved by this registry. These investors will have to KYC via a different registrar in order to be able to transfer their tokens.

Compromised Issuer/Custodian Authority
--------------------------------------

If an IssungEntity or Custodian authority is hacked or found to be acting in bad faith, the owner can restrict the authority using ``IssuingEntity.setAuthorityApprovedUntil``. Further actions will depend on the severity of the actions performed by the compromised account prior to it being frozen.

This situation can be mitigated agiainst with multi-sig requirements, method permissioning, and temporary approval to authorities.
